switch("outdir", "bin")
switch("path", getCurrentDir())

task osx_build, "build for macos":
  setCommand("objc")
  switch("passL", "-framework Cocoa")
  switch("forceBuild", "on")
  switch("define", "release")

task osx_run, "build and run for macos":
  setCommand("objc")
  switch("passL", "-framework Cocoa")
  switch("forceBuild")
  switch("define", "release")
  switch("run")

task osx_run_safe, "build and run for macos w/o optimizations":
  setCommand("objc")
  switch("passL", "-framework Cocoa")
  switch("forceBuild")
  switch("run")

task win_build, "build for windows":
  setCommand("c")
  switch("forceBuild", "on")
  switch("define", "release")

task win_run, "build and run for windows":
  setCommand("c")
  switch("forceBuild", "on")
  switch("define", "release")
  switch("run")
