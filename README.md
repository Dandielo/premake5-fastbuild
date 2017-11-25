# Premake5-fastbuild
A premake5 module for generation of fastbuild projects. 

## Disclaimer
This module is not stable, and is under heavy development. You can try to use it but I don't guarantee any success at this moment. 

## Installation 
The installation should be quite easy if you know lua a bit, I will hoverer provide the premake5 way.

* Create a 'modules' directory in your main premake5.lua location.
* Clone this repository in the 'modules' directory under the 'fastbuild' location. ``cd modules && git clone https://github.com/Dandielo/premake5-fastbuild.git fastbuild``
* Add in your main premake5.lua file the following line ``require "fastbuild"``

### Remarks
So far this module works only on Windows machines with Visual Studio Community or Profesional installed.

### Visual Studio projects
You can generate FastBuild targets which can be used to generate a Visual Studio soluton which uses FastBuild instead of the default compiler.

To enable this feature you need to use ``--fb-vstudio`` command line argument when generating fastbuild projects with premake5.

## Contribute 
Any help is welcome!
Right now there are no official guides, but any pull request should at least try to improve the codebase!


