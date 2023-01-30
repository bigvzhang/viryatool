# Introduction
- Functions: The tools here are used to help copy/link files.

- Problem resolving
  - the tools such as cp, rsync are good, but sometimes it's not easy to be used
  - sometimes, we need re-run copy commands repeatly or regularly
  - some copy commands are related
# Tools

## mkln 
Link files according to a configuration file, for example create one lnk.sh, which maps my local repository to github repository, in directory /d/MyVirya
```
#!env mkln
/d/MyTour/VicSHTour=>./viryatour/bash
    shtour
    -m *.sh  test[[:digit:]][[:digit:]]_
/d/MyWorkbook/scripts/VTools=>./viryatool
   vcommon.sh
   vcommon_ln.sh
   mkln
# line 1: use mkln as shell interpreter
# line 2: set source directory and target directory
# line 3: link file shtour from the source to  the target
# line 4: link files like *.sh, and change file name(test1_arg.sh => arg.sh)
# line 5: a new section, set source and target directories
# line 6-8: link the files
```
    
  
