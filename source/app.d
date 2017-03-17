import std.stdio;

import std.process;
import std.file;
import std.datetime;
import std.algorithm;
import std.array;
import std.json;
import std.getopt;
import jsonizer.fromjson;
import jsonizer.tojson;
import jsonizer.jsonize;
import net.masterthought.rainbow;
import core.thread;
import std.digest.sha;
import std.range;
import std.socket;
import std.net.curl;
import std.conv;

struct EntryPoint
{
  mixin JsonizeMe;

  @jsonize
  {
    string baseDirectory;
    string entryFile;
    string outputFile;
  }

}

struct Watch
{
  mixin JsonizeMe;

  @jsonize
  {
    string baseDirectory;
    string[] fileTypes;
    string[] exclusions;
  }

}

struct Reload
{
  mixin JsonizeMe;

  @jsonize
  {
    bool enabled;
    string port;
    string entryFile;
  }

}

struct Config
{
   mixin JsonizeMe;

   @jsonize
   {
    EntryPoint[] entryPoints;
    Watch watch;
    Reload reload;
    string[] commands;
    string[string] variables;
   }
}

struct FileChanged
{
  string fileName;
  bool changed;
}

class ElmReload {

  Config config;
  alias VT = ubyte[20];
  VT[string] fileMap;
  alias EP = EntryPoint[];
  string rootDir;
  string watchBaseDir;
  string port;
  int reloadDuration;

  this(Config config, string currentDir, int reloadDuration){
    this.config = config;
    this.rootDir = currentDir;
    this.watchBaseDir = currentDir ~ "/" ~ applyVariables(applyVariables(config.watch.baseDirectory));
    this.port = getPort();
    this.reloadDuration = reloadDuration;
  }

  public void runOnce(){
    executeCommands();
    compileElm();
  }

  public void reload(){
    runOnce();
    appendLiveReload();

    if(this.config.reload.enabled){
      writeln(("reload wait time set to: " ~ to!string(this.reloadDuration) ~ " ms").rainbow.magenta);
      liveReloadServer();
    }

    writeln("watching......");

    while(true){
      tryExecute((){
        auto fileChange = hasFileChanged();
        if(fileChange.changed){
           runOnce();
           appendLiveReload();

           if(this.config.reload.enabled){
             liveReloadNotify(fileChange.fileName);
           }

          writeln("watching.......");
        }
      });
      Thread.sleep( dur!("msecs")( this.reloadDuration ) );
    }
  }

 private string applyVariables(string content){
   foreach(key, value ; this.config.variables){
     content = content.replace("£" ~ key, value);
     content = content.replace("£root", this.rootDir);
   }
   return content;
 }

  private void executeCommands(){
    foreach( command ; this.config.commands){
      command = applyVariables(applyVariables(command));
      writeln("running command: ".rainbow.magenta, command.rainbow.lightBlue);
      executeShell(command);
    }
  }

  private string getPort(){
    return this.config.reload.port == "auto" ? getFreePort() : this.config.reload.port;
  }

  private void liveReloadNotify(string file){
   auto url = "http://localhost:" ~ this.port ~ "/changed?files=" ~ file;
   get(url);
  }

  private void appendLiveReload(){
    auto targetFile = applyVariables(applyVariables(this.config.reload.entryFile));
    auto content = std.file.readText(targetFile);
    content = content.replace("</head>", `<script src="http://localhost:` ~ this.port ~ `/livereload.js"></script></head>`);
    std.file.write(targetFile, content);
  }

  private void checkLRDeps(){
    auto cmd = "npm list -g tiny-lr";
    auto exec = executeShell(cmd);
    if(exec.status !=0){
      writeln("[ERROR] - could not execute npm command: " ~ cmd);
      writeln(exec.output.rainbow.lightRed);
      } else {
        auto output = exec.output;
        if(canFind("ERR!",output)){
          writeln(output.rainbow.lightRed);
          writeln("attempting to auto install tiny-lr");
          auto cmd2 = "npm install -g tiny-lr && npm link tiny-lr";
          writeln("running command: " ~ cmd2);
          auto exec2 = executeShell(cmd2);
          if(exec.status !=0){
            writeln("[ERROR] - could not execute npm command: " ~ cmd2);
            writeln(exec2.output.rainbow.lightRed);
          } else {
            writeln("Successfully installed and linked tiny-lr live reload server!".rainbow.lightGreen);
            writeln(output.rainbow.lightGreen);
          }
        } else {
          writeln("Great you have everything needed for live reload!".rainbow.lightGreen);
        }
      }
  }

  private void liveReloadServer(){
    writeln("checking live reload dependencies");
    checkLRDeps();
    auto server = `"var port = ` ~ this.port ~ `;var tinylr = require('tiny-lr'); tinylr().listen(port, function() {console.log('Live reload listening on port: %s', port);})"`;
    auto cmd = "node -e " ~ server;
    spawnShell(cmd);
  }

  private static string getFreePort()
  {
    Socket server = new TcpSocket();
    server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
    server.bind(new InternetAddress(0));
    Address address = server.localAddress;
    server.close();
    return address.toPortString;
  }

  private void compileElm(){
   writeln("compiling elm");

   EP[string] entryPointMap;

   foreach(ep ; this.config.entryPoints){
     auto outFile = applyVariables(applyVariables(ep.outputFile));
     if(outFile in entryPointMap){
       entryPointMap[outFile] ~= ep;
     } else {
       entryPointMap[outFile] = [ep];
     }
   }

   foreach(key, value ; entryPointMap){
      process(value);
   }
  }

  private void process(EntryPoint[] entries){
    if(hasSameBaseDir(entries)){
       auto baseDir = applyVariables(applyVariables(entries.front.baseDirectory));
       auto outputFile = applyVariables(applyVariables(entries.front.outputFile));
       auto filesToCompile = entries.map!(e => applyVariables(applyVariables(e.entryFile))).array.join(" ");
       auto cmd = "cd " ~  baseDir ~ " && elm-make --yes --warn " ~ filesToCompile ~ " --output " ~ outputFile;
       writeln(cmd);
       auto exec = executeShell(cmd);
       if(exec.status !=0){
         writeln("[ERROR] - could not execute elm-make");
         writeln(exec.output.rainbow.lightRed);
       } else {
          auto output = exec.output;
          if(canFind("ERROR",output)){
            writeln(output.rainbow.lightRed);
          } else {
            writeln(output.rainbow.lightGreen);
          }
       }
    } else {
      writeln("[ERROR] - when compiling multiple entrypoints into the same output.js they must all have the same baseDir");
    }
  }


  private bool hasSameBaseDir(EntryPoint[] entries) {
    return entries.map!(e => e.baseDirectory).uniq.array.length == 1;
  }

  private bool containsNoExclusion(string value){
    foreach(ex ; this.config.watch.exclusions){
        if(canFind(value, ex)){
          return false;
        }
    }
    return true;
  }

  private FileChanged hasFileChanged(){
    auto filePattern = "*.{" ~ this.config.watch.fileTypes.join(",") ~ "}";
    auto filesToCheck = dirEntries(this.watchBaseDir,filePattern, SpanMode.depth);
    auto filesToCheckModified = filesToCheck.array.filter!(f => containsNoExclusion(f.name)).array;
    foreach(aFile ; filesToCheckModified){
      if(isFile(aFile)){
        auto key = aFile.name;

          auto currentValue = sha1Of(std.file.read(aFile.name));

          if(key in this.fileMap){
            if(this.fileMap[key] != currentValue){
              writeln("file was modified: " ~ key);
              this.fileMap[key] = currentValue;
              return FileChanged(aFile.name, true);
            }
          } else {
            this.fileMap[key] = currentValue;
          }

      }
    }
    return FileChanged("", false);
  }

  private void tryExecute(void delegate() runnable){
    try{
      runnable();
    } catch (Exception e){

      writeln("[ERROR] something unexpected happened - here is the exception: ");
      writeln("\n--------------------------------------------------------\n");
      writeln(e);
      writeln("\n--------------------------------------------------------\n");

      writeln("\n\n[RETRY] trying again anyway in 5 seconds");
       Thread.sleep( dur!("seconds")(5) );
      tryExecute(runnable);

    }
  }

}

bool run;
bool watch;
bool showHelp = false;
int duration = 1500;
bool ver;
bool ex;

void main(string[] args)
{

  auto example = `
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
`;

  auto currentDir = getcwd();
  showHelp = args.length == 1;

  auto configFile = currentDir ~ "/elm-reload-config.json";
  if(!configFile.exists){
    writeln("Missing config file: ".rainbow.lightRed, configFile.rainbow.lightRed);
    writeln("Creating missing config file".rainbow.lightCyan);
    writeln("Writing example elm-reload-config.json".rainbow.lightCyan);
    std.file.write(configFile, example);
    writeln("Please go and edit the file with real data".rainbow.lightMagenta);
    writeln("vim ", configFile);
  } else {

    arraySep = ",";
    auto helpInformation = getopt(
      args,
      "run|r", "Run the compiler once only", &run,
      "watch|w", "Watch file changes and run in a loop", &watch,
      "duration|d", "Set the reload duration in ms (defaults to " ~ to!string(duration) ~ ")", &duration,
      "version|v",    "Shows version of this app", &ver,
      "example|e",    "Shows example config", &ex
    );

    auto currentVersion = "v0.0.1";

    if(helpInformation.helpWanted || showHelp)
    {
      defaultGetoptPrinter("Elm Reload - simple build tool " ~ currentVersion.rainbow.lightCyan, helpInformation.options);
    }

   // start doing the stuff

   auto config = configFile.readJSON!(Config);
   auto elmReload = new ElmReload(config, currentDir, duration);

   if(watch){
     elmReload.reload();
   } else if(run) {
     elmReload.runOnce();
   } else if(ver){
      writeln("Elm Reload - simple build tool ".rainbow.lightMagenta, currentVersion.rainbow.lightCyan);
   } else if(ex){
     writeln("Example config:", example);
   } else {
     // do nothing
   }


  }

}
