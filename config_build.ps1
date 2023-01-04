$FSO = New-Object -ComObject Scripting.FileSystemObject
$cache = Join-Path $Env:USERPROFILE ".gradle/caches/jdks"
New-Item -Path $cache -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$buildDir = Join-Path $PSScriptRoot "build"
New-Item -Path $buildDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

function findInCache($sha256, $size) {
  (Get-ChildItem -Path $cache | Where-Object -Property Length -EQ $size) | Foreach-Object {
    if ((Get-FileHash -Path $_.FullName -Algorithm SHA256).hash.tolower() -eq $sha256) {
      return $_.FullName
    }
  }
}
function installJdk([String] $version, [String] $destination) {
  foreach ($type in @("ea", "ga")) {
    $assets = Invoke-RestMethod -Uri ('https://api.adoptium.net/v3/assets/feature_releases/' + $version + '/' + $type + '?architecture=x64&image_type=jdk&os=windows&page=0&page_size=1&sort_method=DATE&sort_order=DESC')
    if ($null -ne $assets) {break}
  }
  $package = $assets.binaries.package
  $source = findInCache $package.checksum $package.size
  if ($null -eq $source) {
    $source = Join-Path $cache $package.name
    Start-BitsTransfer -Source $package.link -Destination $source
  }
  New-Item -Path $destination -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
  Expand-Archive -Path $source -DestinationPath $destination
}

foreach ($JDKVersion in @( 8, 11, 17, 19, 20 ) ) {
  $installIn = Join-Path $buildDir "jdk$($JDKVersion)x64"
  $javac = Get-Childitem –Path $installIn -Include javac.exe -File -Recurse -ErrorAction SilentlyContinue
  if ($null -eq $javac) {
    Write-Host "Preparing new local JDK $JDKVersion"
    installJdk $JDKVersion $installIn
    $javac = Get-Childitem –Path $installIn -Include javac.exe -File -Recurse -ErrorAction SilentlyContinue
  }

  $res = (& $javac.PSPath -version 2>&1 ) -join ""
  if  ($res -match 'javac ') {
    Write-Host "Using local JDK $JDKVersion"
    $jdkhome = $FSO.GetFile($javac).ParentFolder.ParentFolder.ShortPath
    Set-Item -Path ("Env:\JAVA_" + $JDKVersion + "_HOME") -Value $jdkhome
  }
}

Write-Host "==="
Write-Host "All set. You can now build BTrace as '.\gradlew :btrace-dist:build'"
