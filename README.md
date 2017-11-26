# Premake5-fastbuild
A premake5 module for generation of fastbuild projects. 

## Disclaimer
This module is not stable, and is under heavy development. You can try to use it but I don't guarantee any success at this moment. 

## Installation 
The installation should be quite easy if you know premake5 and lua.
You can also follow the steps below:

* Create a 'modules' directory in your main premake5.lua location.
* Clone this repository in the 'modules' directory under the 'fastbuild' location. ``cd modules && git clone https://github.com/Dandielo/premake5-fastbuild.git fastbuild``
* Add in your main premake5.lua file the following line ``require "fastbuild"``

### Remarks
So far this module works only on Windows machines with Visual Studio Community or Profesional installed.

### Command line options 
All additional premake5 command line options available with this module. 

#### --fb-vstudio 
Whith this option you can generate FastBuild targets which can be used to generate a Visual Studio soluton which uses FastBuild instead of the default compiler.

The generated fastbuild target will have the following name ``{workspace_name}_sln`` which you can build with the following command ``fbuild -config {workspace_name}.wks.bff {workspace_name}_sln``.

#### --fb-cache-path=PATH
Sets the ``.CachePath`` entry in the Settings section in the fastbuild ``{workspace}.wks.bff`` file. This can be used instead of setting the ``FASTBUILD_CACHE_PATH`` enviroment variable. 

## Contribute 
Any help is welcome!
Right now there are no official guides, but any pull request should at least try to improve the codebase!


