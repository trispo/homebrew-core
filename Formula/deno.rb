class Deno < Formula
  desc "Secure runtime for JavaScript and TypeScript"
  homepage "https://deno.land/"
  url "https://github.com/denoland/deno/releases/download/v1.32.2/deno_src.tar.gz"
  sha256 "9ff0ee1451bf4b543f43ccde6a8d1a53ead8650c1331a92fffee60180900af09"
  license "MIT"
  head "https://github.com/denoland/deno.git", branch: "main"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "c63a4dfac040fdfe57871c11fdcc089701cf174c6654bdfdfc71611abe0cf441"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "001a8b18bee1170f0cec617ea09aa377456b4008d44aa3627cf1fb6b24e459f2"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "42301d14ed3211081797b840f61352610c844247ea11255056932c8fcebc2033"
    sha256 cellar: :any_skip_relocation, ventura:        "e439fdbee20c71c3705f1a1c46f9b21fc01e4d7a491f0808a8996102996cd208"
    sha256 cellar: :any_skip_relocation, monterey:       "2ccf13ef269560e9f102e9badd4f03a5b704add441ef24fd69d51ed88c7427b2"
    sha256 cellar: :any_skip_relocation, big_sur:        "7f53eba1bd0d36c93c986ca662686f8106e2e41a543fae6b13a6e7f57283b2a5"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "abf183dbd5e62479c4e827e6cd4bd149d9bd68a1b53cfd5f37c00edb3c7ef34c"
  end

  depends_on "llvm" => :build
  depends_on "ninja" => :build
  depends_on "python@3.11" => :build
  depends_on "rust" => :build

  uses_from_macos "xz"

  on_macos do
    depends_on xcode: ["10.0", :build] # required by v8 7.9+
  end

  on_linux do
    depends_on "pkg-config" => :build
    depends_on "glib"
  end

  fails_with gcc: "5"

  # Temporary resources to work around build failure due to files missing from crate
  # We use the crate as GitHub tarball lacks submodules and this allows us to avoid git overhead.
  # TODO: Remove this and `v8` resource when https://github.com/denoland/rusty_v8/issues/1065 is resolved
  resource "rusty-v8" do
    url "https://static.crates.io/crates/v8/v8-0.68.0.crate"
    sha256 "81c69410b7435f1b74e82e243ba906d71e8b9bb350828291418b9311dbd77222"
  end

  resource "v8" do
    url "https://github.com/denoland/v8/archive/02aef2fce7750d472d84fa361df3946d447a6489.tar.gz"
    sha256 "60dbd81e1a676b7d174f0fa8e563b224ec0986e21e2776f608a879fa6f118d9b"
  end

  # To find the version of gn used:
  # 1. Find v8 version: https://github.com/denoland/deno/blob/v#{version}/Cargo.toml#L46
  # 2. Find ninja_gn_binaries tag: https://github.com/denoland/rusty_v8/tree/v#{v8_version}/tools/ninja_gn_binaries.py#L21
  # 3. Find short gn commit hash from commit message: https://github.com/denoland/ninja_gn_binaries/tree/#{ninja_gn_binaries_tag}
  # 4. Find full gn commit hash: https://gn.googlesource.com/gn.git/+/#{gn_commit}
  resource "gn" do
    url "https://gn.googlesource.com/gn.git",
        revision: "70d6c60823c0233a0f35eccc25b2b640d2980bdc"
  end

  def install
    # Work around files missing from crate
    # TODO: Remove this at the same time as `rusty-v8` + `v8` resources
    (buildpath/"v8").mkpath
    resource("rusty-v8").stage do |r|
      system "tar", "--strip-components", "1", "-xzvf", "v8-#{r.version}.crate", "-C", buildpath/"v8"
    end
    resource("v8").stage do
      cp_r "tools/builtins-pgo", buildpath/"v8/v8/tools/builtins-pgo"
    end
    inreplace "Cargo.toml",
              /^v8 = { version = ("[\d.]+"),.*}$/,
              "v8 = { version = \\1, path = \"./v8\" }"

    if OS.mac? && (MacOS.version < :mojave)
      # Overwrite Chromium minimum SDK version of 10.15
      ENV["FORCE_MAC_SDK_MIN"] = MacOS.version
    end

    python3 = "python3.11"
    # env args for building a release build with our python3, ninja and gn
    ENV.prepend_path "PATH", Formula["python@3.11"].libexec/"bin"
    ENV["PYTHON"] = Formula["python@3.11"].opt_bin/python3
    ENV["GN"] = buildpath/"gn/out/gn"
    ENV["NINJA"] = Formula["ninja"].opt_bin/"ninja"
    # build rusty_v8 from source
    ENV["V8_FROM_SOURCE"] = "1"
    # Build with llvm and link against system libc++ (no runtime dep)
    ENV["CLANG_BASE_PATH"] = Formula["llvm"].prefix

    resource("gn").stage buildpath/"gn"
    cd "gn" do
      system python3, "build/gen.py"
      system "ninja", "-C", "out"
    end

    # cargo seems to build rusty_v8 twice in parallel, which causes problems,
    # hence the need for -j1
    # Issue ref: https://github.com/denoland/deno/issues/9244
    system "cargo", "install", "-vv", "-j1", *std_cargo_args(path: "cli")

    generate_completions_from_executable(bin/"deno", "completions")
  end

  test do
    (testpath/"hello.ts").write <<~EOS
      console.log("hello", "deno");
    EOS
    assert_match "hello deno", shell_output("#{bin}/deno run hello.ts")
    assert_match "console.log",
      shell_output("#{bin}/deno run --allow-read=#{testpath} https://deno.land/std@0.50.0/examples/cat.ts " \
                   "#{testpath}/hello.ts")
  end
end
