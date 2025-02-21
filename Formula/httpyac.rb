require "language/node"

class Httpyac < Formula
  desc "Quickly and easily send REST, SOAP, GraphQL and gRPC requests"
  homepage "https://httpyac.github.io/"
  url "https://registry.npmjs.org/httpyac/-/httpyac-6.3.4.tgz"
  sha256 "76a5c10217722db90ab21d81c76f9f31c1507806c084f3b874f993fc623ff8ae"
  license "MIT"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "f8f2bf4ceb18300ba24787a28f3900ed0b2bb8a327bec7aa1abf0390db2a759f"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "f8f2bf4ceb18300ba24787a28f3900ed0b2bb8a327bec7aa1abf0390db2a759f"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "f8f2bf4ceb18300ba24787a28f3900ed0b2bb8a327bec7aa1abf0390db2a759f"
    sha256 cellar: :any_skip_relocation, ventura:        "92e85c3df3d1636dea041537d5645b705504ce25534da9905594710ea8165218"
    sha256 cellar: :any_skip_relocation, monterey:       "92e85c3df3d1636dea041537d5645b705504ce25534da9905594710ea8165218"
    sha256 cellar: :any_skip_relocation, big_sur:        "92e85c3df3d1636dea041537d5645b705504ce25534da9905594710ea8165218"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "dfd6c87618a3f63ffb80e31fe3d0c7a9e5be0cbfc53586aeee317c4b296e466c"
  end

  depends_on "node"

  on_linux do
    depends_on "xsel"
  end

  def install
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir[libexec/"bin/*"]

    clipboardy_fallbacks_dir = libexec/"lib/node_modules/#{name}/node_modules/clipboardy/fallbacks"
    clipboardy_fallbacks_dir.rmtree # remove pre-built binaries
    if OS.linux?
      linux_dir = clipboardy_fallbacks_dir/"linux"
      linux_dir.mkpath
      # Replace the vendored pre-built xsel with one we build ourselves
      ln_sf (Formula["xsel"].opt_bin/"xsel").relative_path_from(linux_dir), linux_dir
    end

    # Replace universal binaries with their native slices
    deuniversalize_machos
  end

  test do
    (testpath/"test_cases").write <<~EOS
      GET https://httpbin.org/anything HTTP/1.1
      Content-Type: text/html
      Authorization: Bearer token

      POST https://countries.trevorblades.com/graphql
      Content-Type: application/json

      query Continents($code: String!) {
          continents(filter: {code: {eq: $code}}) {
            code
            name
          }
      }

      {
          "code": "EU"
      }
    EOS

    output = shell_output("#{bin}/httpyac send test_cases --all")
    # for httpbin call
    assert_match "HTTP/1.1 200  - OK", output
    # for graphql call
    assert_match "\"name\": \"Europe\"", output
    assert_match "2 requests processed (2 succeeded, 0 failed)", output

    assert_match version.to_s, shell_output("#{bin}/httpyac --version")
  end
end
