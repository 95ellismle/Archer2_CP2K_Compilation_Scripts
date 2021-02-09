# Archer2 Compilation Scripts

To compile the code run the compilation script as:

    ./compile_CP2K_archer2.sh

This should download the correct version of the code from github and then download and install the correct dependencies. The script will then copy the arch file into the correct folder and make CP2K.

To change the behaviour of the script change the config.sh file.

The settings available in config.sh are as follows (this is a bash script so use bash syntax):

---
* BRANCH="code_extension_V2_archer2"

*The branch of flavoured-cptk to compile*

---
* CLEAN_INSTALL=False

*Whether to completely remove everything before installing with a fresh install*

---
* ARCH_FILE=archer2.sopt

*The name of the make file settings for archer (shouldn't change unless you know what you're doing)*

---
* DO_ELPA=""
* DO_LIBINT=""
* DO_LIBXC=""
* DO_LIBXSMM=""

*Whether to install libraries options are:*
  * _True = (re)install always_
  * _False = don't install_
  * _"" = install if we haven't installed before_


---
SSH_FILENAME="id_rsa.pub"

_The name of the ssh filename to check before pulling the flavoured-cptk directory. If you don't want to do the check set this to an empty string_


NOTE: This only works with the patched version of CP2K otherwise the script will fail trying to compile CP2K.
