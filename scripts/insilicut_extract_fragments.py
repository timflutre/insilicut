#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Aim: extract non-overlapping fragments in a given size range from a BED file
# containing restriction sites from in silico RAD-seq
# Copyright (C) 2014-2015 Institut National de la Recherche Agronomique (INRA)
# License: GPL-3+
# Persons: Timothée Flutre [cre,aut]
# Versioning: https://github.com/timflutre/insilicut

# to allow code to work with Python 2 and 3
from __future__ import print_function   # print is a function in python3
from __future__ import unicode_literals # avoid adding "u" to each string
from __future__ import division # avoid writing float(x) when dividing by x

import sys
import os
import getopt
import time
import datetime
from subprocess import Popen, PIPE
import math
import gzip
import copy
import numpy as np

if sys.version_info[0] == 2:
    if sys.version_info[1] < 7:
        msg = "ERROR: Python should be in version 2.7 or higher"
        sys.stderr.write("%s\n\n" % msg)
        sys.exit(1)
        
progVersion = "1.1.2" # http://semver.org/


class Bed(object):
    def __init__(self, chrom, start, end, name, score=None, strand=None):
        self.chrom = chrom
        self.start = int(start) # 0-based
        self.end = int(end)
        self.name = name
        self.score = int(score) if score else None
        self.strand = strand
    def __len__(self):
        return self.end - self.start
    def __repr__(self):
        txt = "%s\t%i\t%i\t%s" % (self.chrom, self.start, self.end, self.name)
        if self.score:
            txt += "\t%i" % self.score
        if self.strand:
            txt += "\t%s" % self.strand
        return txt
    
    
class ExtractFragments(object):
    
    def __init__(self):
        self.verbose = 1
        self.inBedFile = ""
        self.minFragSize = 1
        self.maxFragSize = 500
        self.outBedPrefix = ""
        
        
    def help(self):
        """
        Display the help on stdout.
        
        The format complies with help2man (http://www.gnu.org/s/help2man)
        """
        msg = "`%s' extracts non-overlapping fragments in a given size range\nfrom a BED file containing restriction sites from in silico RAD-seq\n" % os.path.basename(sys.argv[0])
        msg += "\n"
        msg += "Usage: %s [OPTIONS] ...\n" % os.path.basename(sys.argv[0])
        msg += "\n"
        msg += "Options:\n"
        msg += " -h, --help\tdisplay the help and exit\n"
        msg += " -V, --version\toutput version information and exit\n"
        msg += " -v, --verbose\tverbosity level (0/default=1/2/3)\n"
        msg += " -i\t\tinput file with the cut sites (BED format, gzipped)\n"
        msg += "\t\tcoordinates should correspond to the whole motif (e.g. 7-11 instead of 9)\n"
        msg += " -s\t\tmin size of the fragments to select (default=1)\n"
        msg += " -S\t\tmax size of the fragments to select (default=500)\n"
        msg += "\n"
        msg += "Remarks:\n"
        msg += " two output files are written, one with all fragments and one with the size-selected fragments"
        msg += "\n"
        msg += "Report bugs to <timothee.flutre@supagro.inra.fr>."
        print(msg); sys.stdout.flush()
        
        
    def version(self):
        """
        Display version and license information on stdout.
        
        The person roles comply with R's guidelines (The R Journal Vol. 4/1, June 2012).
        """
        msg = "%s %s\n" % (os.path.basename(sys.argv[0]), progVersion)
        msg += "\n"
        msg += "Copyright (C) 2014-2015 Institut National de la Recherche Agronomique (INRA).\n"
        msg += "License GPL-3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>\n"
        msg += "This is free software; see the source for copying conditions. There is NO\n"
        msg += "warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n"
        msg += "\n"
        msg += "Written by Timothée Flutre [cre,aut]."
        print(msg.encode("utf8")); sys.stdout.flush()
        
        
    def setAttributesFromCmdLine(self):
        """
        Parse the command-line arguments.
        """
        try:
            opts, args = getopt.getopt( sys.argv[1:], "hVv:i:s:S:",
                                        ["help", "version", "verbose="])
        except getopt.GetoptError, err:
            sys.stderr.write("%s\n" % str(err))
            self.help()
            sys.exit(2)
        for o, a in opts:
            if o == "-h" or o == "--help":
                self.help()
                sys.exit(0)
            elif o == "-V" or o == "--version":
                self.version()
                sys.exit(0)
            elif o == "-v" or o == "--verbose":
                self.verbose = int(a)
            elif o == "-i":
                self.inBedFile = a
            elif o == "-s":
                self.minFragSize = int(a)
            elif o == "-S":
                self.maxFragSize = int(a)
            else:
                assert False, "unhandled option"
                
                
    def checkAttributes(self):
        """
        Check the values of the command-line parameters.
        """
        if self.inBedFile == "":
            msg = "ERROR: missing compulsory option -i"
            sys.stderr.write("%s\n\n" % msg)
            self.help()
            sys.exit(1)
        if not os.path.exists(self.inBedFile):
            msg = "ERROR: can't find '%s'" % self.inBedFile
            sys.stderr.write("%s\n\n" % msg)
            self.help()
            sys.exit(1)
        self.outBedPrefix = self.inBedFile.split(".bed.gz")[0]
        
        
    def loadBedFile(self):
        if self.verbose > 0:
            sys.stdout.write("read file %s ..." % self.inBedFile)
            sys.stdout.flush()
        inBedH = gzip.open(self.inBedFile)
        lines = inBedH.readlines()
        inBedH.close()
        if self.verbose > 0:
            sys.stdout.write(" done\n")
        return lines
    
    
    def parseLines(self, lines):
        dChr2sites = {}
        for line in lines:
            tokens = line.rstrip().split("\t")
            if tokens[0] not in dChr2sites:
                dChr2sites[tokens[0]] = []
            dChr2sites[tokens[0]].append(Bed(tokens[0], tokens[1], tokens[2],
                                             tokens[3]))
        return dChr2sites
    
    
    def getNonOverlappingFragments(self, dChr2sites):
        lFrags = []
        if self.verbose > 0:
            msg = "get non-overlapping fragments ..."
            print(msg); sys.stdout.flush()
        chroms = dChr2sites.keys()
        chroms.sort()
        
        for chrom in chroms:
            if self.verbose > 0:
                msg = "%s: %i cuts" % (chrom, len(dChr2sites[chrom]))
            dChr2sites[chrom].sort(key=lambda x: x.start)
            nbFrags = 0
            for i in xrange(1, len(dChr2sites[chrom])):
                if dChr2sites[chrom][i-1].end < dChr2sites[chrom][i].start:
                    frag = Bed(chrom,
                               dChr2sites[chrom][i-1].end,
                               dChr2sites[chrom][i].start,
                               "%s_%s" % (dChr2sites[chrom][i-1].name, dChr2sites[chrom][i].name))
                    lFrags.append(frag)
                    nbFrags += 1
            if self.verbose > 0:
                msg += " and %i fragments" % nbFrags
                print(msg); sys.stdout.flush()
                
        if self.verbose > 0:        
            lenFrags = np.array([len(x) for x in lFrags], dtype=int)
            print("nb of fragments: %i (mean-len=%.2f std-err=%f std-dev=%.2f min=%i Q25=%.2f med=%i Q75=%.2f max=%i)" \
                  % (len(lFrags), np.mean(lenFrags),
                     np.std(lenFrags)/math.sqrt(len(lFrags)),
                     np.std(lenFrags),
                     np.min(lenFrags),
                     np.percentile(lenFrags, 25),
                     np.median(lenFrags),
                     np.percentile(lenFrags, 75),
                     np.max(lenFrags)))
        return lFrags
        
        
    def saveFragments(self, lFrags):
        if self.verbose > 0:        
            print("save fragments of the good size ...")
            sys.stdout.flush()
        outBedAllFile = "%s_frags.bed.gz" % self.outBedPrefix
        outBedAllH = gzip.open(outBedAllFile, "w")
        outBedSelFile = "%s_frags_s-%i_S-%i.bed.gz" % (self.outBedPrefix,
                                                       self.minFragSize,
                                                       self.maxFragSize)
        outBedSelH = gzip.open(outBedSelFile, "w")
        nbKeptFrags = 0
        for frag in lFrags:
            outBedAllH.write("%s\n" % frag)
            if len(frag) >= self.minFragSize and \
               len(frag) <= self.maxFragSize:
                outBedSelH.write("%s\n" % frag)
                nbKeptFrags += 1
        outBedAllH.close()
        outBedSelH.close()
        if self.verbose > 0:        
            print("nb of kept fragments: %i" % nbKeptFrags)
            
            
    def run(self):
        lines = self.loadBedFile()
        dChr2sites = self.parseLines(lines)
        lFrags = self.getNonOverlappingFragments(dChr2sites)
        self.saveFragments(lFrags)
        
        
if __name__ == "__main__":
    i = ExtractFragments()
    
    i.setAttributesFromCmdLine()
    
    i.checkAttributes()
    
    if i.verbose > 0:
        startTime = time.time()
        msg = "START %s %s" % (os.path.basename(sys.argv[0]),
                               time.strftime("%Y-%m-%d %H:%M:%S"))
        msg += "\ncmd-line: %s" % ' '.join(sys.argv)
        msg += "\ncwd: %s" % os.getcwd()
        print(msg); sys.stdout.flush()
        
    i.run()
    
    if i.verbose > 0:
        msg = "END %s %s" % (os.path.basename(sys.argv[0]),
                             time.strftime("%Y-%m-%d %H:%M:%S"))
        endTime = time.time()
        runLength = datetime.timedelta(seconds=
                                       math.floor(endTime - startTime))
        msg += " (%s" % str(runLength)
        if "linux" in sys.platform:
            p = Popen(["grep", "VmHWM", "/proc/%s/status" % os.getpid()],
                      shell=False, stdout=PIPE).communicate()
            maxMem = p[0].split()[1]
            msg += "; %s kB)" % maxMem
        else:
            msg += ")"
        print(msg); sys.stdout.flush()
