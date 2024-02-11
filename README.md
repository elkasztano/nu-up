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

### On Windows

* downloads latest release (.msi file) to the user's Download folder
* simply launches the Windows msi installer
    * _important note:_ Nushell is running during the installation, so you will probably get a 'Files in Use' warning
    * check 'Do not close applications.', click `OK` button
    * the above described warning may occur twice during the installation
    * restart nu if necessary

## Usage

### clone repository and navigate to it

`git clone "https://github.com/elkasztano/nu-up" && cd nu-up`

### run script

`nu up.nu`

## Notes

* the above mentioned target directories may be easily changed in the script itself
* the directory where the symlink is created should be in your PATH
* update from Nushell version 0.89.0 to 0.90.1 was tested on Debian 12 (x86_64), Windows 11 (x86_64) and Raspberry Pi OS Bookworm (aarch64)
* use at your own risk
