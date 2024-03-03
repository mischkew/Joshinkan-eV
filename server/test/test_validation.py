import pytest
from joshinkan.validation import (
    DictOf,
    InvalidSchema,
    ListOf,
    Optional,
    OptionalKey,
    Schema,
    TypeOf,
    TypeOr,
    Values,
)


class MyTestType:
    pass


class TestTypeOf:
    def test_typeof(self):
        assert TypeOf(list).validate([]) == (True, None)
        assert TypeOf(int).validate(5) == (True, None)
        assert TypeOf(MyTestType).validate(MyTestType()) == (True, None)

    def test_typeof_invalid_without_path(self):
        is_valid, invalid_schema = TypeOf(list).validate(5)
        assert not is_valid
        assert invalid_schema.path is None
        assert (
            "value 5 has an unexpected type of <class 'int'>" in invalid_schema.message
        )
        assert "Expected <class 'list'>" in invalid_schema.message

    def test_typeof_invalid_with_path(self):
        is_valid, invalid_schema = TypeOf(list).validate(5, path="hello.there")
        assert not is_valid
        assert invalid_schema.path == "hello.there"
        assert (
            "value 5 at 'hello.there' has an unexpected type of <class 'int'>"
            in invalid_schema.message
        )
        assert "Expected <class 'list'>" in invalid_schema.message


class TestValues:
    def test_values(self):
        my_obj = MyTestType()
        assert Values(1, 2, 3).validate(1) == (True, None)
        assert Values(None, "hello", dict, my_obj).validate(my_obj) == (True, None)
        assert Values(None, "hello", dict, my_obj).validate("hello") == (True, None)
        assert Values(None, "hello", dict, my_obj).validate(None) == (True, None)

    def test_fail_without_path(self):
        is_valid, invalid_schema = Values(1, 2, 3).validate(5)
        assert not is_valid
        assert invalid_schema.path is None
        assert "value is 5. Expected one of (1, 2, 3)" in invalid_schema.message

    def test_fail_with_path(self):
        is_valid, invalid_schema = Values(1, 2, 3).validate(5, "hello.there")
        assert not is_valid
        assert invalid_schema.path == "hello.there"
        assert (
            "value of 'hello.there' is 5. Expected one of (1, 2, 3)"
            in invalid_schema.message
        )


class TestListOf:
    def test_listof(self):
        assert ListOf(int).validate([1, 2, 3]) == (True, None)
        assert ListOf(int).validate([]) == (True, None)
        assert ListOf(str).validate(["test"]) == (True, None)

    def test_listof_with_typeof(self):
        assert ListOf(TypeOf(str)).validate(["test"]) == (True, None)
        assert ListOf(Values(1, 2, 3)).validate([1, 1, 2]) == (True, None)

    def test_fail_without_path(self):
        is_valid, invalid_schema = ListOf(int).validate(["test"])
        assert not is_valid
        assert invalid_schema.path == "[0]"
        assert (
            "value test at '[0]' has an unexpected type of <class 'str'>. Expected <class 'int'>"
            in invalid_schema.message
        )

    def test_fail_with_path(self):
        is_valid, invalid_schema = ListOf(int).validate([3, "test"], "hello.there")
        assert not is_valid
        assert invalid_schema.path == "hello.there[1]"
        assert (
            "value test at 'hello.there[1]' has an unexpected type of <class 'str'>"
            in invalid_schema.message
        )
        assert "Expected <class 'int'>" in invalid_schema.message

    def test_fail_without_list_type_without_path(self):
        is_valid, invalid_schema = ListOf(int).validate(2)
        assert not is_valid
        assert invalid_schema.path is None
        assert (
            "value 2 has an unexpected type of <class 'int'>" in invalid_schema.message
        )
        assert "Expected <class 'list'>" in invalid_schema.message

    def test_fail_without_list_type_with_path(self):
        is_valid, invalid_schema = ListOf(int).validate(2, "hello.there")
        assert not is_valid
        assert invalid_schema.path is "hello.there"
        assert (
            "value 2 at 'hello.there' has an unexpected type of <class 'int'>"
            in invalid_schema.message
        )
        assert "Expected <class 'list'>" in invalid_schema.message


class TestTypeOr:
    def test_typeor(self):
        assert TypeOr(int, float).validate(5) == (True, None)
        assert TypeOr(int, float).validate(5.0) == (True, None)

    def test_fail_without_path(self):
        is_valid, invalid_schema = TypeOr(int, float).validate("hi")
        assert not is_valid
        assert invalid_schema.path is None
        assert (
            "value hi has an unexpected type of <class 'str'>" in invalid_schema.message
        )
        assert (
            "Expected one of [<class 'int'>, <class 'float'>]" in invalid_schema.message
        )

    def test_fail_with_path(self):
        is_valid, invalid_schema = TypeOr(int, float).validate("hi", "hello.there")
        assert not is_valid
        assert invalid_schema.path == "hello.there"
        assert (
            "value hi at 'hello.there' has an unexpected type of <class 'str'>"
            in invalid_schema.message
        )
        assert (
            "Expected one of [<class 'int'>, <class 'float'>]" in invalid_schema.message
        )

    def test_nested_typeor(self):
        assert TypeOr(Values(1, 2, 3), ListOf(float)).validate(1) == (True, None)
        assert TypeOr(Values(1, 2, 3), ListOf(float)).validate([1.0]) == (True, None)
        assert not TypeOr(Values(1, 2, 3), ListOf(float)).validate(4)[0]
        assert not TypeOr(Values(1, 2, 3), ListOf(float)).validate([1])[0]


class TestSchema:
    def test_validate_no_dict(self):
        is_valid, invalid_schema = Schema({"a": int}).validate(5)
        assert not is_valid
        assert invalid_schema.path is None
        assert (
            "value 5 has an unexpected type of <class 'int'>. Expected <class 'dict'>."
            in invalid_schema.message
        )

    def test_simple_dict(self):
        schema = {"a": int, "b": str, "c": MyTestType}
        obj = {"a": 1, "b": "hallo", "c": MyTestType()}

        assert Schema(schema).validate(obj) == (True, None)

    def test_unexpected_type(self):
        schema = {"a": int}
        obj = {"a": 1.0}

        is_valid, invalid_schema = Schema(schema).validate(obj)
        assert not is_valid
        assert invalid_schema.path == "a"
        assert (
            "value 1.0 at 'a' has an unexpected type of <class 'float'>. Expected <class 'int'>"
            in invalid_schema.message
        )

    def test_missing_key(self):
        schema = {"a": int, "b": str, "c": MyTestType}
        obj = {"a": 1, "b": "hallo"}

        is_valid, invalid_schema = Schema(schema).validate(obj)
        assert not is_valid
        assert invalid_schema.path == "c"
        assert "The key 'c' is missing" in invalid_schema.message

    def test_optional_key(self):
        schema = {"a": int, OptionalKey("b"): str}
        obj1 = {"a": 1, "b": "hallo"}
        obj2 = {"a": 1}
        obj3 = {"a": 1, "b": 2}

        assert Schema(schema).validate(obj1) == (True, None)
        assert Schema(schema).validate(obj2) == (True, None)

        is_valid, invalid_schema = Schema(schema).validate(obj3)
        assert not is_valid
        assert invalid_schema.path == "b"
        assert (
            "value 2 at 'b' has an unexpected type of <class 'int'>. Expected <class 'str'>"
            in invalid_schema.message
        )

    def test_unexpected_key(self):
        schema = {"a": int}
        obj = {"a": 1, "b": 2}

        is_valid, invalid_schema = Schema(schema).validate(obj)
        assert not is_valid
        assert invalid_schema.path == "b"
        assert "The key 'b' is not defined in the schema." in invalid_schema.message

    def test_nested_schema(self):
        schema = {"region": Schema({"a": int})}
        obj = {"region": {"a": 1}}

        assert Schema(schema).validate(obj) == (True, None)


class TestListOfSchema:
    def test_listof_schema_valid(self):
        assert ListOf(Schema({"a": int})).validate([{"a": 1}]) == (True, None)

    def test_listof_schema_invalid(self):
        is_valid, invalid_schema = ListOf(Schema({"a": int})).validate([{"b": 1}])
        assert not is_valid
        assert invalid_schema.path == "[0].a"
        assert "The key '[0].a' is missing." in invalid_schema.message


class TestDictOf:
    def test_dictof(self):
        assert DictOf(key_type=str, value_type=int).validate({"a": 1}) == (True, None)
        assert DictOf(key_type=int, value_type=str).validate({1: "a"}) == (True, None)
        assert DictOf(key_type=int, value_type=str).validate({}) == (True, None)
        assert DictOf(key_type=TypeOr(int, str), value_type=ListOf(int)).validate(
            {"a": [1], 2: [2]}
        ) == (True, None)

    def test_non_empty(self):
        is_valid, invalid_schema = DictOf(
            key_type=str, value_type=int, allow_empty=False
        ).validate({})
        assert not is_valid
        assert invalid_schema.path is None
        assert "The dict cannot be empty" in invalid_schema.message

    def test_nested_dictof(self):
        assert DictOf(key_type=str, value_type=Schema({"a": int})).validate(
            {"b": {"a": 1}}
        ) == (True, None)

    def test_missing_nesting(self):
        is_valid, invalid_schema = DictOf(key_type=str, value_type=int).validate(5)
        assert not is_valid
        assert invalid_schema.path is None
        assert (
            "The value 5 has an unexpected type of <class 'int'>. Expected <class 'dict'>."
            in invalid_schema.message
        )

    def test_unexpected_key_type(self):
        is_valid, invalid_schema = DictOf(key_type=str, value_type=object).validate(
            {1: 1}
        )
        assert not is_valid
        assert invalid_schema.path == "1"
        assert (
            "The key at '1' has an unexpected type of <class 'int'>. Expected TypeOf(<class 'str'>)"
            in invalid_schema.message
        )

    def test_invalid_value(self):
        is_valid, invalid_schema = DictOf(
            key_type=str, value_type=Values(1, 2)
        ).validate({"1": None})
        assert not is_valid
        assert invalid_schema.path == "1"
        assert (
            "The value of '1' is None. Expected one of (1, 2)."
            in invalid_schema.message
        )

    def test_invalid_value_with_path(self):
        is_valid, invalid_schema = DictOf(
            key_type=str, value_type=Values(1, 2)
        ).validate({"1": None}, "hello.there")
        assert not is_valid
        assert invalid_schema.path == "hello.there.1"
        assert (
            "The value of 'hello.there.1' is None. Expected one of (1, 2)."
            in invalid_schema.message
        )


class TestOptional:
    def test_optional_values(self):
        assert Optional(str).validate(None) == (True, None)
        assert Optional(int).validate(1) == (True, None)
        assert Optional(TypeOf(int)).validate(1) == (True, None)

    def test_optional_with_wrong_type(self):
        is_valid, invalid_schema = Optional(str).validate(1)
        assert not is_valid
        assert invalid_schema.path is None
        assert (
            "he value 1 has an unexpected type of <class 'int'>."
            " Expected one of [<class 'NoneType'>, <class 'str'>]"
            in invalid_schema.message
        )
