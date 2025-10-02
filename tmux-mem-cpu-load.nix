{ lib
, stdenv
, fetchFromGitHub
, cmake
}:

stdenv.mkDerivation rec {
  pname = "tmux-mem-cpu-load";
  version = "show_cpu_show_ram";

  src = fetchFromGitHub {
    owner = "ormandi";
    repo = "tmux-mem-cpu-load";
    rev = "e027f746ab4db4ff0520439d53f6b0257c68ab44";
    hash = "sha256-vovlwgQ/FZ5+CmXmNHKrQrzIeSJZ6fPmYFW8RHaynYc=";
  };

  nativeBuildInputs = [ cmake ];

  meta = with lib; {
    description = "CPU, RAM memory, and load monitor for use with tmux";
    homepage = "https://github.com/ormandi/tmux-mem-cpu-load";
    license = licenses.asl20;
    platforms = platforms.unix;
  };
}
