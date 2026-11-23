#!/usr/bin/env python3
"""Empacota uma pasta de extensão (com package.json) como .vsix.

Uso: make-vsix.py <pasta-da-extensão> <saida.vsix>

Um .vsix é um zip com a pasta em extension/, um extension.vsixmanifest e um
[Content_Types].xml. Usado para levar o pacote de português dentro do
instalador, quando não dá para baixar do Open VSX.
"""
import json
import os
import sys
import zipfile
from xml.sax.saxutils import escape

src, out = sys.argv[1], sys.argv[2]
pkg = json.load(open(os.path.join(src, "package.json"), encoding="utf-8"))
ident = f'{pkg["publisher"]}.{pkg["name"]}'
manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{escape(pkg["name"])}" Version="{escape(pkg["version"])}" Publisher="{escape(pkg["publisher"])}"/>
    <DisplayName>{escape(pkg.get("displayName", pkg["name"]))}</DisplayName>
    <Description xml:space="preserve">{escape(pkg.get("description", ""))}</Description>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{escape(pkg["engines"]["vscode"])}"/>
    </Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
"""
types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
  <Default Extension=".md" ContentType="text/markdown"/>
  <Default Extension=".png" ContentType="image/png"/>
  <Default Extension=".js" ContentType="application/javascript"/>
</Types>
"""
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", types)
    z.writestr("extension.vsixmanifest", manifest)
    for dirpath, _, files in os.walk(src):
        for f in files:
            full = os.path.join(dirpath, f)
            z.write(full, "extension/" + os.path.relpath(full, src).replace(os.sep, "/"))
print(f"{ident} {pkg['version']} -> {out}")
