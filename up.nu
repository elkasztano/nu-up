#!/usr/bin/env nu

# import log module from the standard library - comes in handy for notifications

use std [log]

def main [] {

# get number of currently installed version

  let currentvers = version | get version

# retrieve latest version number

  let vers = (
    http head -R manual "https://github.com/nushell/nushell/releases/latest" | where name == "location" | get value | split row '/' | last
  )

# exit with 0 if current version is the latest version

  if $currentvers == $vers {
    print "You are up to date!"
    exit 0
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

  let dl_path = ( get_dlpath $dl_file $system_os )

  let fullurl = $"https://github.com/nushell/nushell/releases/download/($vers)/($dl_file)"

# download procedure / check if file has already been downloaded

  if ( $dl_path | path exists ) {

    log warning "File has already been downloaded."

  } else {

    log info "Starting download..."
    http get $fullurl | save --progress $dl_path

  }

  install $dl_path $system_os

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

def get_dlpath [ out_file, system_os ] {
   
  if ($system_os starts-with "Linux") {

    # change download directory here
    let dldir = $"($env.HOME)/Downloads"
    
    chkdir $dldir

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

def install [ tar_path, system_os ] {

  if ($system_os starts-with "Linux") {

    let softwaredir = $"($env.HOME)/Software" # tar extraction directory
    chkdir $softwaredir

    let binary_dir = $"($env.HOME)/bin" # should be PATH
    chkdir $binary_dir

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

    if not ( $binary_dir | path exists) {
      log critical $"directory '($binary_dir)' not found - exiting"
      exit 1
    } else {
      log info $"creating symlink: '($symlinkdir)' -> '($binary_dir)'"
      ^ln -sf $symlinkdir $binary_dir
    }

  } else if ($system_os starts-with "Windows") {

    # simply start installation of msi package
    print $tar_path
    run-external $"($env.SystemRoot)\\System32\\msiexec.exe" "/i" $tar_path
  
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
