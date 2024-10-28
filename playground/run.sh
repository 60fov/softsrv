if [ -z "$1" ]; then
  echo "must provide a program"
  (zig build -l | tail -n +3 | grep -oP "^\s+\w+")
else
  zig build $1 --release=fast && zig-out/bin/$1
fi
