-- Unit tests for utils module
describe("utils module", function()
  local utils

  before_each(function()
    -- Clear package cache to ensure fresh load
    package.loaded["claude-code.utils"] = nil
    utils = require("claude-code.utils")
  end)

  describe("string utilities", function()
    describe("trim function", function()
      it("should remove leading and trailing whitespace", function()
        assert.are.equal("hello", utils.string.trim("  hello  "))
        assert.are.equal("world", utils.string.trim("\\t\\nworld\\n\\t"))
        assert.are.equal("test", utils.string.trim("test"))
        assert.are.equal("", utils.string.trim("   "))
      end)

      it("should handle nil and empty strings", function()
        assert.are.equal("", utils.string.trim(nil))
        assert.are.equal("", utils.string.trim(""))
      end)

      it("should preserve internal whitespace", function()
        assert.are.equal("hello world", utils.string.trim("  hello world  "))
        assert.are.equal("a b c", utils.string.trim("\\ta b c\\n"))
      end)
    end)

    describe("is_empty function", function()
      it("should identify empty strings", function()
        assert.is_true(utils.string.is_empty(""))
        assert.is_true(utils.string.is_empty("   "))
        assert.is_true(utils.string.is_empty("\\t\\n"))
        assert.is_true(utils.string.is_empty(nil))
      end)

      it("should identify non-empty strings", function()
        assert.is_false(utils.string.is_empty("hello"))
        assert.is_false(utils.string.is_empty("  hello  "))
        assert.is_false(utils.string.is_empty("0"))
      end)
    end)

    describe("split function", function()
      it("should split string by delimiter", function()
        local result = utils.string.split("a,b,c", ",")
        assert.are.same({"a", "b", "c"}, result)
      end)

      it("should handle single item", function()
        local result = utils.string.split("hello", ",")
        assert.are.same({"hello"}, result)
      end)

      it("should handle empty string", function()
        local result = utils.string.split("", ",")
        assert.are.same({}, result)
      end)

      it("should handle nil input", function()
        local result = utils.string.split(nil, ",")
        assert.are.same({}, result)
      end)
    end)

    describe("escape_pattern function", function()
      it("should escape regex special characters", function()
        assert.are.equal("hello%.", utils.string.escape_pattern("hello."))
        assert.are.equal("test%*", utils.string.escape_pattern("test*"))
        assert.are.equal("%(hello%)", utils.string.escape_pattern("(hello)"))
      end)

      it("should handle nil input", function()
        assert.are.equal("", utils.string.escape_pattern(nil))
      end)
    end)
  end)

  describe("table utilities", function()
    describe("deep_copy function", function()
      it("should create deep copy of table", function()
        local original = { a = 1, b = { c = 2, d = { e = 3 } } }
        local copy = utils.table.deep_copy(original)
        
        assert.are.same(original, copy)
        assert.are_not.equal(original, copy)
        assert.are_not.equal(original.b, copy.b)
        assert.are_not.equal(original.b.d, copy.b.d)
      end)

      it("should handle non-table values", function()
        assert.are.equal("hello", utils.table.deep_copy("hello"))
        assert.are.equal(42, utils.table.deep_copy(42))
        assert.is_nil(utils.table.deep_copy(nil))
      end)
    end)

    describe("is_empty function", function()
      it("should identify empty tables", function()
        assert.is_true(utils.table.is_empty({}))
        assert.is_true(utils.table.is_empty(nil))
      end)

      it("should identify non-empty tables", function()
        assert.is_false(utils.table.is_empty({ a = 1 }))
        assert.is_false(utils.table.is_empty({ 1, 2, 3 }))
      end)
    end)

    describe("deep_merge function", function()
      it("should merge tables deeply", function()
        local target = { a = 1, b = { c = 2 } }
        local source = { b = { d = 3 }, e = 4 }
        local result = utils.table.deep_merge(target, source)
        
        assert.are.same({
          a = 1,
          b = { c = 2, d = 3 },
          e = 4
        }, result)
      end)

      it("should handle non-table inputs", function()
        local result = utils.table.deep_merge(nil, { a = 1 })
        assert.are.same({ a = 1 }, result)
        
        local result2 = utils.table.deep_merge({ a = 1 }, nil)
        assert.are.same({ a = 1 }, result2)
      end)
    end)
  end)

  describe("validation utilities", function()
    describe("non_empty_string function", function()
      it("should validate non-empty strings", function()
        assert.is_true(utils.validate.non_empty_string("hello"))
        assert.is_true(utils.validate.non_empty_string("  test  "))
      end)

      it("should reject empty strings and non-strings", function()
        assert.is_false(utils.validate.non_empty_string(""))
        assert.is_false(utils.validate.non_empty_string("   "))
        assert.is_false(utils.validate.non_empty_string(nil))
        assert.is_false(utils.validate.non_empty_string(42))
        assert.is_false(utils.validate.non_empty_string({}))
      end)
    end)

    describe("is_function function", function()
      it("should identify functions", function()
        assert.is_true(utils.validate.is_function(function() end))
        assert.is_true(utils.validate.is_function(print))
      end)

      it("should reject non-functions", function()
        assert.is_false(utils.validate.is_function("hello"))
        assert.is_false(utils.validate.is_function(42))
        assert.is_false(utils.validate.is_function({}))
        assert.is_false(utils.validate.is_function(nil))
      end)
    end)

    describe("is_table function", function()
      it("should identify tables", function()
        assert.is_true(utils.validate.is_table({}))
        assert.is_true(utils.validate.is_table({ a = 1 }))
      end)

      it("should reject non-tables", function()
        assert.is_false(utils.validate.is_table("hello"))
        assert.is_false(utils.validate.is_table(42))
        assert.is_false(utils.validate.is_table(function() end))
        assert.is_false(utils.validate.is_table(nil))
      end)
    end)
  end)

  describe("file utilities", function()
    describe("get_extension function", function()
      it("should extract file extensions", function()
        assert.are.equal("lua", utils.file.get_extension("test.lua"))
        assert.are.equal("txt", utils.file.get_extension("/path/to/file.txt"))
        assert.are.equal("tar.gz", utils.file.get_extension("archive.tar.gz"))
      end)

      it("should handle files without extensions", function()
        assert.are.equal("", utils.file.get_extension("filename"))
        assert.are.equal("", utils.file.get_extension("/path/to/filename"))
      end)

      it("should handle nil input", function()
        assert.are.equal("", utils.file.get_extension(nil))
      end)
    end)

    describe("get_basename function", function()
      it("should extract basenames", function()
        assert.are.equal("test", utils.file.get_basename("test.lua"))
        assert.are.equal("file", utils.file.get_basename("/path/to/file.txt"))
      end)

      it("should handle files without extensions", function()
        assert.are.equal("filename", utils.file.get_basename("filename"))
        assert.are.equal("filename", utils.file.get_basename("/path/to/filename"))
      end)

      it("should handle nil input", function()
        assert.are.equal("", utils.file.get_basename(nil))
      end)
    end)
  end)

  describe("string metatable extension", function()
    it("should add trim method to strings", function()
      assert.are.equal("hello", ("  hello  "):trim())
    end)

    it("should add split method to strings", function()
      assert.are.same({"a", "b", "c"}, ("a,b,c"):split(","))
    end)

    it("should add is_empty method to strings", function()
      assert.is_true(("   "):is_empty())
      assert.is_false(("hello"):is_empty())
    end)
  end)
end)