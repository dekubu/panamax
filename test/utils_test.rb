require "test_helper"

class UtilsTest < ActiveSupport::TestCase
  test "argumentize" do
    assert_equal [ "--label", "foo=\"\\`bar\\`\"", "--label", "baz=\"qux\"", "--label", :quux ], \
      Pnmx::Utils.argumentize("--label", { foo: "`bar`", baz: "qux", quux: nil })
  end

  test "argumentize with redacted" do
    assert_kind_of SSHKit::Redaction, \
      Pnmx::Utils.argumentize("--label", { foo: "bar" }, sensitive: true).last
  end

  test "argumentize_env_with_secrets" do
    ENV.expects(:fetch).with("FOO").returns("secret")

    args = Pnmx::Utils.argumentize_env_with_secrets({ "secret" => [ "FOO" ], "clear" => { BAZ: "qux" } })

    assert_equal [ "-e", "FOO=[REDACTED]", "-e", "BAZ=\"qux\"" ], Pnmx::Utils.redacted(args)
    assert_equal [ "-e", "FOO=\"secret\"", "-e", "BAZ=\"qux\"" ], Pnmx::Utils.unredacted(args)
  end

  test "optionize" do
    assert_equal [ "--foo", "\"bar\"", "--baz", "\"qux\"", "--quux" ], \
      Pnmx::Utils.optionize({ foo: "bar", baz: "qux", quux: true })
  end

  test "optionize with" do
    assert_equal [ "--foo=\"bar\"", "--baz=\"qux\"", "--quux" ], \
      Pnmx::Utils.optionize({ foo: "bar", baz: "qux", quux: true }, with: "=")
  end

  test "no redaction from #to_s" do
    assert_equal "secret", Pnmx::Utils.sensitive("secret").to_s
  end

  test "redact from #inspect" do
    assert_equal "[REDACTED]".inspect, Pnmx::Utils.sensitive("secret").inspect
  end

  test "redact from SSHKit output" do
    assert_kind_of SSHKit::Redaction, Pnmx::Utils.sensitive("secret")
  end

  test "redact from YAML output" do
    assert_equal "--- ! '[REDACTED]'\n", YAML.dump(Pnmx::Utils.sensitive("secret"))
  end

  test "escape_shell_value" do
    assert_equal "\"foo\"", Pnmx::Utils.escape_shell_value("foo")
    assert_equal "\"\\`foo\\`\"", Pnmx::Utils.escape_shell_value("`foo`")

    assert_equal "\"${PWD}\"", Pnmx::Utils.escape_shell_value("${PWD}")
    assert_equal "\"${cat /etc/hostname}\"", Pnmx::Utils.escape_shell_value("${cat /etc/hostname}")
    assert_equal "\"\\${PWD]\"", Pnmx::Utils.escape_shell_value("${PWD]")
    assert_equal "\"\\$(PWD)\"", Pnmx::Utils.escape_shell_value("$(PWD)")
    assert_equal "\"\\$PWD\"", Pnmx::Utils.escape_shell_value("$PWD")

    assert_equal "\"^(https?://)www.example.com/(.*)\\$\"",
      Pnmx::Utils.escape_shell_value("^(https?://)www.example.com/(.*)$")
    assert_equal "\"https://example.com/\\$2\"",
      Pnmx::Utils.escape_shell_value("https://example.com/$2")
  end
end
