#!/usr/bin/env nu

# import log module from the standard library - comes in handy for notifications

use std [log]

def main [ --tryenv (-e) ] {

# get number of currently installed version

  let currentvers = version | get version

# retrieve latest version number

  let vers = (
    http head -R manual "https://github.com/nushell/nushell/releases/latest" | where name == "location" | get value | split row '/' | last
  )

# exit with 0 if current version is the latest version
# exit with error code if unable to retrieve latest version number

  if $currentvers == $vers {
    print "You are up to date!"
    exit 0
  } else if $vers == null {
    log critical "unable to retrieve latest version number - exiting"
    exit 1
  } else {
    print $"Version '($vers)' available!"
  }

# retrieve system os and check for dependencies

  let system_os = (sys).host.long_os_version

  check_dependencies $system_os

# compose paths / select appropriate file for architecture and os

  let build_target = version | get build_target

  let tar_file = ( select_installer $build_target )

  let dl_file = $"nu-($vers)-($tar_file)"

  let dl_path = ( get_dlpath $dl_file $system_os $tryenv )

  let fullurl = $"https://github.com/nushell/nushell/releases/download/($vers)/($dl_file)"

# download procedure / check if file has already been downloaded

  if ( $dl_path | path exists ) {

    log warning "File has already been downloaded."

  } else {

    log info "Starting download..."
    http get $fullurl | save --progress $dl_path

  }

  install $dl_path $system_os $tryenv

}


def select_installer [ build_target ] {

# select installation file by matching build target of currently installed version
# you might want to modify this according to your requirements

  if $build_target == "x86_64-unknown-linux-gnu" {
    
    "x86_64-linux-gnu-full.tar.gz"

  } else if $build_target == "aarch64-unknown-linux-gnu" {
    
    "aarch64-linux-gnu-full.tar.gz"

  } else if $build_target == "x86_64-pc-windows-msvc" {

    "x86_64-windows-msvc-full.msi"

  } else {

    log critical $"build target '($build_target)' currently unsupported - exiting"
    exit 1

  }

}


# get download path / check if download directory exists

def get_dlpath [ out_file, system_os, tryenv ] {
   
  if ($system_os starts-with "Linux") {

    let dldir = if $tryenv {

      $nu.temp-path

    } else {

      # change download directory here
      $"($env.HOME)/Downloads"

    }

    if not $tryenv { chkdir $dldir }

    $"($dldir)/($out_file)"
  
  } else if ($system_os starts-with "Windows") {

    # change download directory here
    let dldir = $"($env.HOMEDRIVE)($env.HOMEPATH)\\Downloads"

    chkdir $dldir

    $"($dldir)\\($out_file)"
  
  } else {
    
    print "currently only Linux or Windows systems supported - exiting"
    exit 1
  
  }

}


# OS dependent installation procedure

def install [ tar_path, system_os, tryenv ] {

  if ($system_os starts-with "Linux") {

    let softwaredir = if $tryenv {
 
      $nu.current-exe | str replace --regex "(/nu-.+)?/nu$" ""
    
    } else {
      
      $"($env.HOME)/Software" # tar extraction directory
    
    }

    if not $tryenv { chkdir $softwaredir } else { chkhome $softwaredir $env.HOME }

    let binary_dir = if $tryenv {
      
      $env._ | str replace --regex '/nu$' ''
         
    } else {

      $"($env.HOME)/bin" # should be PATH

    }

    if $tryenv {

      chkhome $binary_dir $env.HOME

      if not ( $env.PATH | any { |it| $it == $binary_dir } ) {
        log critical $"'($binary_dir)' not PATH - exiting"
        exit 1
      }
    
    } else {

      chkdir $binary_dir

    }

    # get name of extracted directory
    let dir = $tar_path | str replace --regex '.+/' "" | str replace --regex '\.tar\.gz' ""

    let symlinkdir = $"($softwaredir)/($dir)/nu"

    if not ( $softwaredir | path exists) {
      log critical $"directory '($softwaredir)' not found - exiting"
      exit 1
    } else {
      log info "extracting tar archive"
      ^tar -xvzf $tar_path -C $softwaredir
    }

    # check config file compatibility with newer nushell version
    check_config $symlinkdir
    
    if not ( $binary_dir | path exists) {
      log critical $"directory '($binary_dir)' not found - exiting"
      exit 1
    } else {
      log info $"creating symlink: '($symlinkdir)' -> '($binary_dir)'"
      ^ln -sf $symlinkdir $binary_dir
    }

  } else if ($system_os starts-with "Windows") {

    # start installation of msi package
    # let Powershell initialize the installation - avoid sharing violations
 
    print $tar_path
    ^pwsh -Command $"msiexec /i ($tar_path)"

  }

}


# check if required external commands are available / in PATH

def check_dependencies [ system_os ] {

  if ($system_os starts-with "Linux") {

    mut d = 0

    for i in [ tar, ln ] {

      if (which $i | is-empty) {
        log warning $"($i) not in PATH"
        $d += 1
      }

    }

    if $d != 0 {
      log critical "missing dependencies - exiting"
      exit 1
    }

  } else if ($system_os starts-with "Windows") {

    if not ( $"($env.SystemRoot)\\System32\\msiexec.exe" | path exists ) {
      log critical "msiexec not found - exiting"
      exit 1
    }
  
  } else {

    log critical "currently only Linux or Windows systems supported - exiting"

  }

}


# check if directory exists
# if not, ask user to create it

def chkdir [ full_path ] {

  if not ( $full_path | path exists ) {
    
    mut answer = ([ "Yes", "No" ]
      | input list $"Directory '($full_path)' does not exist - create it?")

    if $answer == "Yes" {

      print $"Creating '($full_path)'."
      
      mkdir -v $full_path
    
    } else {
      
      log critical $"Proceeding without '($full_path)' not possible - exiting."
      
      exit 1
    
    }
  
  }

}

# check if directory is a subdirectory (of e.g. $HOME)

def chkhome [ full_path, home_path ] {
  
  if not ( $full_path starts-with $home_path ) {
    
    log warning $"'($full_path)' not in '($home_path)'"
    
    mut answer = ([ "Yes", "No" ]
      | input list $"Contents of '($full_path)' are about to be modified. Continue?")

    if $answer == "No" {
      log critical "update interrupted by user"
      exit 1
    }

  }

}

# rudimentary config file compatibility check

def check_config [ new_nushell_path ] {

  let errors = ((do { ^$"($new_nushell_path)" -e 'exit' } | complete).stderr)

  if ( $errors | is-empty ) {
    
    log info "config files seem to be compatible with new Nushell version"
  
  } else {
    
    log warning "rudimentary config file compatibility check failed"
    print $"errors:\n~~~\n($errors)\n~~~\n"
    
    mut answer = ([ "Yes", "No" ]
      | input list "Continue anyway?")
    
    if $answer == "No" {
      
      log critical "update interrupted by user"
      exit 1
    
    } else {
      log warning "continuing installation - please check your config files"
    
    }
  
  }

}
