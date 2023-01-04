$jdks =  @{
	8 = @{ url = "https://api.adoptium.net/v3/installer/latest/8/ga/windows/x64/jdk/hotspot/normal/eclipse"; };
	11= @{ url = "https://api.adoptium.net/v3/installer/latest/11/ga/windows/x64/jdk/hotspot/normal/eclipse"; defaultJDK = $true; };
	17= @{ url = "https://api.adoptium.net/v3/installer/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"; };
	19= @{ url = "https://api.adoptium.net/v3/installer/latest/19/ga/windows/x64/jdk/hotspot/normal/eclipse"; };
	20= @{ url = "https://api.adoptium.net/v3/installer/latest/20/ea/windows/x64/jdk/hotspot/normal/eclipse"; };
}
$buildDir = Join-Path $PSScriptRoot "build"

New-Item -Path $buildDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

ForEach ($JDKVersion in $jdks.Keys) {
  $jdk = $jdks[$JDKVersion]
  $jdk.msi = Join-Path $Env:TEMP "jdk$($JDKVersion)x64.msi"
  $jdk.installIn = Join-Path $buildDir "jdk$($JDKVersion)x64"
  New-Item -Path $jdk.installIn -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

  $javac = Get-Childitem –Path $jdk.installIn -Include javac.exe -File -Recurse -ErrorAction SilentlyContinue
  if ($null -eq $javac) {
    Write-Host "Preparing new local JDK $JDKVersion"
    Start-BitsTransfer -Source $jdk.url -Destination $jdk.msi
	  Start-Process -Wait -NoNewWindow "msiexec.exe" -ArgumentList @("/a"; $jdk.msi; "ADDLOCAL=FeatureMain"; "TARGETDIR=""" + $jdk.installIn + """"; "/qn")
    $javac = Get-Childitem –Path $jdk.installIn -Include javac.exe -File -Recurse -ErrorAction SilentlyContinue
  }

  $res = (& $javac.PSPath -version 2>&1 ) -join ""
  if  ($res -match 'javac ') {
    Write-Host "Using local JDK $JDKVersion"
    $jdk.home = $javac.Directory.Parent.FullName
    Set-Item -Path ("Env:\JAVA_" + $JDKVersion + "_HOME") -Value $jdk.home
  }

  if ($jdk.defaultJDK) {
    Write-Host "Locally setting JDK $JDKVersion as default"
    $Env:JAVA_HOME = $jdk.home
    $binPath = Join-Path $jdk.home "bin"
    $Env:PATH = "${binPath};${Env:PATH}"
  }
}

Write-Host "==="
Write-Host "All set. You can now build BTrace as '.\gradlew :btrace-dist:build'"
