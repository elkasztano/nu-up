# nu-up

Nushell update helper script

## What it does

* follows the redirect on "https://github.com/nushell/nushell/releases/latest" in order to retrieve the latest version number

* checks if the currently installed version of Nushell is the latest version

### On Linux

* downloads latest release (.tar.gz file) to `$HOME/Downloads`
* extracts its content to `$HOME/Software`
* creates a symlink of the 'nu' binary in `$HOME/bin`
* if one of the above listed directories does not exist, the user will be prompted to create it
* a very basic config file compatibility check is made
    * if the config file check fails the user must confirm first in order to proceed with the installation
* with the `--tryenv` flag set, the script will try to collect information from environment variables (see below)

### On Windows

* downloads latest release (.msi file) to the user's Download folder
* starts the msi installer from within Powershell to avoid sharing violation

## Usage

### clone repository and navigate to it

`git clone "https://github.com/elkasztano/nu-up" && cd nu-up`

### run script

`nu up.nu`

### Optional: use environment variables

`nu up.nu --tryenv`

* with the 'tryenv' flag set the script makes use of various environment variables in order to gather information about the current directory layout
* a warning will be shown and the user will be prompted to confirm if the script is about to modifiy anything outside `$HOME` (except `$nu.temp-path`)
* the archive is downloaded to `$nu.temp-path`
* the precompiled binary is extracted in the parent directory of `$nu.current-exe`
    * if that directory starts with 'nu-', then the directory above will be used
* the symlink is created in the parent directory of `$env._`

## Notes

* please check the compatibility of your config files first before upgrading to a newer version of Nushell
* the above mentioned target directories may be easily changed in the script itself
* the directory where the symlink is created should be in your PATH
* update from Nushell version 0.89.0 to 0.90.1 was tested on Debian 12 (x86_64), Windows 11 (x86_64) and Raspberry Pi OS Bookworm (aarch64)
* use at your own risk
