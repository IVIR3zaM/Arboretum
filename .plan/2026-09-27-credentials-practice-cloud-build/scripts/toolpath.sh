# toolpath.sh — source me. Puts the toolchains bootstrap.sh installs on PATH for non-interactive
# shells (cold runs, verify.sh), which read neither .bashrc nor .profile. Idempotent: each dir is
# prepended only if it exists and is not already on PATH.
for _toolpath_dir in "$HOME/.cargo/bin" "$HOME/flutter-sdk/bin"; do
  if [ -d "$_toolpath_dir" ]; then
    case ":${PATH:-}:" in
      *":$_toolpath_dir:"*) ;;
      *) PATH="$_toolpath_dir${PATH:+:$PATH}" ;;
    esac
  fi
done
unset _toolpath_dir
export PATH
