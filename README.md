# Elm Reload

A simple build tool and very basic webpack replacement

Currently it only works and is tested on OSX. It will probably work fine on linux based systems
but has not been tested. It's not going to work on Windows platforms - if you want it to work on 
Windows platforms - raise an issue and I will make it so. 

## Usage

The binary can do 2 things

* run - run once
* watch - watch for file changes and run on file change

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
          "baseDirectory" : "path/to/elm-package.json/relative/to/directory/elm-reload/is/executed/in",
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
        
## Installation

You can either download the binary from this repo for OSX. or you can build the source using the D language. 

To build the source do the following:

* install the DMD compiler for your platform - https://dlang.org/download.html#dmd
* install the dub package manager for your platform - https://code.dlang.org/download
* clone this repo and in the root of the project run - dub build 
* this will generate the elm-reload binary in the root directory which you can then use

## Help

Raise an issue if you need assistance.