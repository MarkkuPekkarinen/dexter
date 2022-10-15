require_relative "test_helper"

class DexterTest < Minitest::Test
  def test_basic_index
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)"
  end

  def test_basic_no_index
    assert_no_index "SELECT * FROM posts"
  end

  def test_multicolumn_order
    assert_index "SELECT * FROM posts WHERE user_id = 1 ORDER BY blog_id LIMIT 1000", "public.posts (user_id, blog_id)"
  end

  def test_update
    assert_index "UPDATE posts SET user_id = 2 WHERE user_id = 1", "public.posts (user_id)"
  end

  def test_delete
    assert_index "DELETE FROM posts WHERE user_id = 1", "public.posts (user_id)"
  end

  def test_view
    assert_index "SELECT * FROM posts_view WHERE view_id = 1", "public.posts (id)"
  end

  def test_materialized_view
    assert_index "SELECT * FROM posts_materialized WHERE id = 1", "public.posts_materialized (id)"
  end

  def test_cte
    assert_index "WITH cte AS (SELECT * FROM posts WHERE id = 1) SELECT * FROM cte", "public.posts (id)"
  end

  def test_cte_fence
    if server_version >= 12
      assert_index "WITH cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1", "public.posts (id)"
    else
      assert_no_index "WITH cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1"
    end
  end

  def test_materialized_cte
    skip if server_version < 12

    assert_no_index "WITH MATERIALIZED cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1"
  end

  def test_order
    assert_index "SELECT * FROM posts ORDER BY user_id DESC LIMIT 10", "public.posts (user_id)"
  end

  def test_order_multiple
    assert_index "SELECT * FROM posts ORDER BY user_id, blog_id LIMIT 10", "public.posts (user_id, blog_id)"
  end

  def test_order_multiple_direction
    skip
    assert_index "SELECT * FROM posts ORDER BY user_id DESC, blog_id LIMIT 10", "public.posts (user_id DESC, blog_id)"
  end

  def test_exclude
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--exclude posts"
  end

  def test_exclude_other
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--exclude other"
  end

  def test_include
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--include posts"
  end

  def test_include_other
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--include other"
  end

  def test_schema
    assert_index "SELECT * FROM \"Bar\".\"Foo\" WHERE \"Id\" = 10000", "Bar.Foo (Id)"
  end

  def test_connection_flag
    assert_connection ["-d", "dexter_test"]
  end

  def test_connection_string
    assert_connection ["dbname=dexter_test"]
  end

  def test_connection_url_postgres
    assert_connection ["postgres:///dexter_test"]
  end

  def test_connection_url_postgresql
    assert_connection ["postgresql:///dexter_test"]
  end

  def test_input_format_stderr
    assert_index_file "queries.log", "stderr"
  end

  def test_input_format_csv
    assert_index_file "queries.csv", "csv"
  end

  def test_input_format_json
    assert_index_file "queries.json", "json"
  end

  def test_input_format_sql
    assert_index_file "queries.sql", "sql"
  end

  def test_min_cost_savings
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--min-cost-savings-pct 100"
  end

  def test_create
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--create"
  ensure
    execute("DROP INDEX posts_id_idx")
  end

  def test_tablespace
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--create --tablespace pg_default"
  ensure
    execute("DROP INDEX posts_id_idx")
  end

  private

  def assert_index(statement, index, options = nil)
    assert_dexter_output "Index found: #{index}", ["-s", statement] + options.to_s.split(" ")
  end

  def assert_index_file(file, input_format)
    file = File.expand_path("../support/#{file}", __FILE__)
    assert_dexter_output "Index found: public.posts (id)", [file, "--input-format", input_format]
  end

  def assert_no_index(statement, options = nil)
    assert_dexter_output "No new indexes found", ["-s", statement] + options.to_s.split(" ")
  end

  def assert_dexter_output(output, options)
    dexter = Dexter::Client.new(["dexter_test"] + options + ["--log-level", "debug2", "--log-sql"])
    stdout, _ = capture_io { dexter.perform }
    puts stdout if ENV["VERBOSE"]
    assert_match output, stdout
  end

  def assert_connection(flags)
    dexter = Dexter::Client.new(flags + ["-s", "SELECT 1"])
    stdout, _ = capture_io { dexter.perform }
    puts stdout if ENV["VERBOSE"]
    assert_match "No new indexes found", stdout
  end

  def server_version
    execute("SHOW server_version_num").first["server_version_num"].to_i / 10000
  end

  def execute(statement)
    $conn.exec(statement)
  end
end
