# Elm Reload

A simple build tool and very basic webpack replacement

Currently it only works and is tested on OSX. It will probably work fine on linux based systems
but has not been tested. It's not going to work on Windows platforms - if you want it to work on 
Windows platforms - raise an issue and I will make it so. 

## Usage

The binary can do 2 things

* run - run once
* watch - watch for file changes and run on file change

## Command line options

* -r : run once
* -w : watch in a loop
* -d : set the wait in milliseconds for watch (defaults to 1500)
* -f : prints out the number of files and extensions watched (useful for optimising the include/exclude files)
* -e : prints an example config 
* -v : prints the version of the binary

## Config

You must supply a configuration file in the directory in which the elm-reload binary is being
executed from. The file is called: elm-reload-config.json

### Example config

    {
      "watch": {
        "baseDirectory": ".",
        "fileTypes": ["elm","html","js"],
        "exclusions": [
          "node_modules",
          "elm-stuff"
        ]
      },
      "reload": {
        "enabled": true,
        "port": "auto",
        "entryFile": "£target/path/to/index.html"
      },
      "variables": {
        "target": "£root/../../../target/classes/main/webapp",
        "app": "£root",
        "common": "£root/../../../../common/app"
      },
      "commands": [
        "rm -rf £target/webapp",
        "mkdir -p £target/app/common/assets/css && lessc £common/common/stylesheets/app/styles.less -x £target/app/common/assets/css/styles.css"
      ],
      "entryPoints" : [
        {
          "baseDirectory" : "base/path/to/locate/entry/and/output/files",
          "entryFile" : "path/to/Main.elm/relative/to/baseDirectory",
          "outputFile" : "path/to/outputFile.js/relative/to/baseDirectory"
        }
      ]
    }
    
### Sections
    
Each section has some config options - all sections are mandatory and must be present in the json even if not required or empty    
    
#### Watch

 | Option         | Description |
 |----------------|-------------|
 | baseDirectory  | base directory to start watching files from - its relative to the directory where the elm-reload binary is executed  |
 | fileTypes      | file extensions to watch |
 | exclusions     | directories to exclude| 
 
#### Reload

This is for live reload so when you make a code change to a file that is being watched the browser will auto reload itself. This is done with websockets - so a script tag is inserted in the index.html of the entry point. This also required you to 
have tiny-lr live reload server installed. If it's not found elm-reload will try to install it using npm.

 | Option         | Description |
 |----------------|-------------|
 | enabled        | true/false - whether live reload is enabled|
 | port           | auto/port number - if auto chooses a random port otherwise uses the port number specified|
 | entryFile      | the entry index.html file for your project - the livereload script tag is inserted in the head of this file|
 
#### Variables

 | Option         | Description |
 |----------------|-------------|
 | variable name  | requires a name and a value |
 
Variables can be used anywhere in the config by using their name prefixed with £ sign - e.g. £target 
There is a build in variable called £root which is the absolute path to the directory that elm-reload is being executed in.

#### Commands

An array of command line item to execute. They are executed in a local shell. You can use the variables defined in the Variables section in here. This is useful for copying files, running the less compiler, install things etc. 
     
#### Entry Points for elm

These are entry points for elm. A list of objects that contain:

* baseDirectory - the base directory from which to find entryFile and outputFile 
* entryFile - the Main.elm file for your project relative to the baseDirectory
* outputFile - the location and filename of the generated js file e.g. js/app.js (relative to baseDirectory)
   
You can build multiple output js files or a single combined js file for multiple Main.elm files.

*Multiple outputs*

For a output.js file per entry point - just make sure each outFile config has a unique name. When run for each entry point
it will cd to the basedirectory - run elm-make on the Main.elm supplied in entryFile and then generate the output to the supplied outputFile. Therefore creating a js output file for each entry point.

*Single output*

For a single output.js containing one or more Main.elm - you need to specify the same outputFile js file for each of the entry points you want to be combined. When run all entry points with the same outputFile will be bundled into a single output file. 

Since everything is relative to the baseDirectory - every entry point that has the same outputFile must also have the same baseDirectory setting.

You can use variables in the config as defined in the Variables section.


## Installation

You can either download the binary from this repo for OSX. or you can build the source using the D language. 

To build the source do the following:

* install the DMD compiler for your platform - https://dlang.org/download.html#dmd
* install the dub package manager for your platform - https://code.dlang.org/download
* clone this repo and in the root of the project run - dub build 
* this will generate the elm-reload binary in the root directory which you can then use

## Help

Raise an issue if you need assistance.