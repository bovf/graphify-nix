{...}:
# graphify (github:safishamsi/graphify) — not in nixpkgs, packaged here.
final: prev: let
  py = prev.python3.pkgs;

  datasketch = py.buildPythonPackage rec {
    pname = "datasketch";
    version = "1.10.0";
    pyproject = true;

    src = prev.fetchPypi {
      inherit pname version;
      hash = "sha256-0jrqgM5MQHkMp6QHlWWYSL6S7MQ9uAlCvibyHoHSRxQ=";
    };

    build-system = [py.hatchling py.hatch-vcs];

    dependencies = with py; [numpy scipy];

    # Tests need a live redis + cassandra.
    doCheck = false;
    pythonImportsCheck = ["datasketch"];

    meta = {
      description = "Probabilistic data structures (MinHash, HyperLogLog) for large-scale similarity";
      homepage = "https://github.com/ekzhu/datasketch";
      license = prev.lib.licenses.mit;
      platforms = prev.lib.platforms.unix;
    };
  };

  # PyPI sdists strip src/tree_sitter/parser.h; fetch from GitHub instead.
  mkTSParser = {
    owner ? "tree-sitter",
    pname,
    version,
    tag ? "v${version}",
    hash,
    module ? null,
  }:
    py.buildPythonPackage {
      inherit pname version;
      pyproject = true;

      src = prev.fetchFromGitHub {
        inherit owner hash;
        repo = pname;
        inherit tag;
      };

      build-system = [py.setuptools];
      doCheck = false;
      pythonImportsCheck = [
        (
          if module != null
          then module
          else builtins.replaceStrings ["-"] ["_"] pname
        )
      ];

      meta = {
        description = "Tree-sitter grammar for ${prev.lib.removePrefix "tree-sitter-" pname} (Python bindings)";
        homepage = "https://github.com/${owner}/${pname}";
        license = prev.lib.licenses.mit;
        platforms = prev.lib.platforms.unix;
      };
    };

  tree-sitter-typescript = mkTSParser {
    pname = "tree-sitter-typescript";
    version = "0.23.2";
    hash = "sha256-CU55+YoFJb6zWbJnbd38B7iEGkhukSVpBN7sli6GkGY=";
  };
  tree-sitter-java = mkTSParser {
    pname = "tree-sitter-java";
    version = "0.23.5";
    hash = "sha256-OvEO1BLZLjP3jt4gar18kiXderksFKO0WFXDQqGLRIY=";
  };
  tree-sitter-groovy = mkTSParser {
    owner = "amaanq";
    pname = "tree-sitter-groovy";
    version = "0.1.2";
    hash = "sha256-usgT3dOq5Tg1wet4jCcS47Dn+2psl7dPRjcimjZClBk=";
  };
  tree-sitter-c = mkTSParser {
    pname = "tree-sitter-c";
    version = "0.24.2";
    hash = "sha256-Juuf57GQI7OAP6O03KtSzyKJAoXtGKjyYJ+sTM1A4mU=";
  };
  tree-sitter-cpp = mkTSParser {
    pname = "tree-sitter-cpp";
    version = "0.23.4";
    hash = "sha256-tP5Tu747V8QMCEBYwOEmMQUm8OjojpJdlRmjcJTbe2k=";
  };
  tree-sitter-ruby = mkTSParser {
    pname = "tree-sitter-ruby";
    version = "0.23.1";
    hash = "sha256-iu3MVJl0Qr/Ba+aOttmEzMiVY6EouGi5wGOx5ofROzA=";
  };
  tree-sitter-kotlin = mkTSParser {
    owner = "tree-sitter-grammars";
    pname = "tree-sitter-kotlin";
    version = "1.1.0";
    hash = "sha256-6jjK5rA/lEdsYDboU7wGfzEiRdZo44SrLlcgWci0xa4=";
  };
  tree-sitter-scala = mkTSParser {
    pname = "tree-sitter-scala";
    version = "0.26.0";
    hash = "sha256-CnTcQFqYp60rGkLVLRHokUwBenqtWV4hw8boFYNRkbw=";
  };
  tree-sitter-php = mkTSParser {
    pname = "tree-sitter-php";
    version = "0.23.9";
    hash = "sha256-MBahoes2e3znxZ5Ajz9/RjRuoMEN4yGf8ycT97s95pA=";
  };
  tree-sitter-lua = mkTSParser {
    owner = "tree-sitter-grammars";
    pname = "tree-sitter-lua";
    version = "0.5.0";
    hash = "sha256-VzaaN5pj7jMAb/u1fyyH6XmLI+yJpsTlkwpLReTlFNY=";
  };
  # plain `<ver>` tag has parser.c gitignored; -with-generated-files commits it.
  tree-sitter-swift = mkTSParser {
    owner = "alex-pinkus";
    pname = "tree-sitter-swift";
    version = "0.7.3";
    tag = "0.7.3-with-generated-files";
    hash = "sha256-SnWwqk6IRpaNldsraSKwHGtS64LiCndxDksrvLMs1P8=";
  };

  # tree-sitter-nix's PyPI 0.1.0 sdist bundles parser.h — no GitHub fetch needed.
  tree-sitter-nix = py.buildPythonPackage {
    pname = "tree-sitter-nix";
    version = "0.1.0";
    pyproject = true;

    src = prev.fetchurl {
      url = "https://files.pythonhosted.org/packages/4d/c2/10d8983cfaf9c336befe77bb0ef4e058b05ca2208589288e84cb83691e15/tree_sitter_nix-0.1.0.tar.gz";
      hash = "sha256-tVH9APu6yS8wD6lB88QbZh8pDBQVWd4PaQ1VCdmsPLA=";
    };

    build-system = [py.setuptools];
    doCheck = false;
    pythonImportsCheck = ["tree_sitter_nix"];

    meta = {
      description = "Tree-sitter grammar for Nix (Python bindings)";
      homepage = "https://github.com/nix-community/tree-sitter-nix";
      license = prev.lib.licenses.mit;
      platforms = prev.lib.platforms.unix;
    };
  };

  # tree-sitter-hcl's PyPI 1.2.0 sdist also bundles parser.h.
  tree-sitter-hcl = py.buildPythonPackage {
    pname = "tree-sitter-hcl";
    version = "1.2.0";
    pyproject = true;

    src = prev.fetchurl {
      url = "https://files.pythonhosted.org/packages/06/c9/ed79f643b0cec3e123171c09caffb6088a6111025a20fc69112b1468828b/tree_sitter_hcl-1.2.0.tar.gz";
      hash = "sha256-+Gy3qf1cuT2D4veIrhVVREZMR3VdCRkFBd5WLA1q0d0=";
    };

    build-system = [py.setuptools];
    doCheck = false;
    pythonImportsCheck = ["tree_sitter_hcl"];

    meta = {
      description = "Tree-sitter grammar for HCL / Terraform / OpenTofu / Terragrunt (Python bindings)";
      homepage = "https://github.com/tree-sitter-grammars/tree-sitter-hcl";
      license = prev.lib.licenses.mit;
      platforms = prev.lib.platforms.unix;
    };
  };

  parserDeps =
    (with py; [
      tree-sitter-python
      tree-sitter-javascript
      tree-sitter-rust
      tree-sitter-c-sharp
      tree-sitter-json
    ])
    ++ [
      tree-sitter-typescript
      tree-sitter-java
      tree-sitter-groovy
      tree-sitter-c
      tree-sitter-cpp
      tree-sitter-ruby
      tree-sitter-kotlin
      tree-sitter-scala
      tree-sitter-php
      tree-sitter-lua
      tree-sitter-swift
      tree-sitter-nix
      tree-sitter-hcl
    ];

  extrasMap = {
    mcp = with py; [mcp];
    neo4j = with py; [neo4j];
    pdf = with py; [pypdf markdownify];
    watch = with py; [watchdog];
    svg = with py; [matplotlib];
    leiden = with py; [graspologic];
    office = with py; [python-docx openpyxl];
    google = with py; [openpyxl];
    video = with py; [faster-whisper yt-dlp];
    kimi = with py; [openai tiktoken];
    ollama = with py; [openai];
    bedrock = with py; [boto3];
    gemini = with py; [openai tiktoken];
    openai = with py; [openai tiktoken];
    chinese = with py; [jieba];
    terraform = [tree-sitter-hcl];
    # sql needs tree-sitter-sql; not in nixpkgs.
  };

  # Parsers in graphify's pyproject that extract.py never uses — relax the
  # buildPythonApplication consistency check by dropping them.
  unpackagedParsers = [
    "tree-sitter-go"
    "tree-sitter-zig"
    "tree-sitter-powershell"
    "tree-sitter-elixir"
    "tree-sitter-objc"
    "tree-sitter-julia"
    "tree-sitter-verilog"
    "tree-sitter-fortran"
    "tree-sitter-bash"
    "tree-sitter-dm"
  ];

  graphifyFor = {extras}: let
    deps = with py;
      [networkx datasketch rapidfuzz tree-sitter]
      ++ parserDeps
      ++ prev.lib.concatMap (k: extrasMap.${k} or []) extras;

    base = py.buildPythonApplication rec {
      pname = "graphifyy";
      version = "0.8.39";
      pyproject = true;

      src = prev.fetchPypi {
        inherit pname version;
        hash = "sha256-eeIG/SHeCQv3FV8KxGE0V5UpXtyDfpDpvMgslhpjE6c=";
      };

      # Local fork: extract_nix and .nix CODE_EXTENSIONS/dispatch.
      patches = [./nix-support.patch];

      build-system = [py.setuptools];

      pythonRemoveDeps = unpackagedParsers;
      pythonRelaxDeps = ["tree-sitter-swift"];

      dependencies = deps;

      doCheck = false;
      pythonImportsCheck = ["graphify"];

      meta = {
        description = "AI coding assistant skill — turns any folder of code/docs into a queryable knowledge graph";
        homepage = "https://github.com/safishamsi/graphify";
        mainProgram = "graphify";
        license = prev.lib.licenses.mit;
        platforms = prev.lib.platforms.unix;
      };
    };

    # graphify-python: Python interpreter with graphify importable for
    # SKILL.md steps. The base graphify wrapper always calls main() so it
    # can't double as `python -c`. toPythonModule lets withPackages accept
    # the buildPythonApplication output.
    pythonEnv = prev.python3.withPackages (_: deps ++ [(py.toPythonModule base)]);
  in
    base.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          ln -sf ${pythonEnv}/bin/python3 $out/bin/graphify-python
        '';

      passthru =
        (old.passthru or {})
        // {
          inherit unpackagedParsers pythonEnv;
        };
    });
in {
  inherit datasketch;
  graphify = prev.lib.makeOverridable graphifyFor {
    extras = ["mcp" "pdf" "svg" "terraform"];
  };
}
