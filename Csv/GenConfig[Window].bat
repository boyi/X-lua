@cd %~dp0..\Tool\CfgGen\
@set rootPath=..\..

ConfigGen.exe -optMode all ^
-configXml %rootPath%\Csv\Cfg.xml ^
-dataDir %rootPath%\GamePlayer\Config ^
-luaDir %rootPath%\Code\Scripts\Cfg ^
-codeDir %rootPath%\Unity\Assets\Editor\Code
REM -xmlCodeDir %rootPath%\Unity\Assets\Editor\XmlCode


