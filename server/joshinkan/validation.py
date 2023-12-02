from typing import Any, List
from typing import Optional as _Optional
from typing import Tuple, Type


class InvalidSchema:
    def __init__(self, message: str, path: str):
        self.message = message
        self.path = path


def empty_dict(path: str) -> InvalidSchema:
    if path:
        return InvalidSchema(f"The dict at '{path}' cannot be empty.", path)
    else:
        return InvalidSchema(f"The dict cannot be empty.", path)


def missing_key(path: str) -> InvalidSchema:
    return InvalidSchema(f"The key '{path}' is missing.", path)


def unexpected_key(path: str) -> InvalidSchema:
    return InvalidSchema(f"The key '{path}' is not defined in the schema.", path)


def unexpected_type(
    actual: Any,
    expected_type: Type,
    path: _Optional[str] = None,
) -> InvalidSchema:
    if path is None:
        return InvalidSchema(
            f"The value {actual} has an unexpected type of {type(actual)}."
            f" Expected {expected_type}.",
            path,
        )
    else:
        return InvalidSchema(
            f"The value {actual} at '{path}' has an unexpected type of {type(actual)}."
            f" Expected {expected_type}.",
            path,
        )


def unexpected_typeor(
    actual: Any,
    expected_types: List["TypeOf"],
    path: _Optional[str] = None,
) -> InvalidSchema:
    if path is None:
        return InvalidSchema(
            f"The value {actual} has an unexpected type of {type(actual)}."
            f" Expected one of {[typeof.expected for typeof in expected_types]}.",
            path,
        )
    else:
        return InvalidSchema(
            f"The value {actual} at '{path}' has an unexpected type of {type(actual)}."
            f" Expected one of {[typeof.expected for typeof in expected_types]}.",
            path,
        )


def unexpected_key_type(
    actual: Any,
    expected_type: Type,
    path: str,
) -> InvalidSchema:
    return InvalidSchema(
        f"The key at '{path}' has an unexpected type of {type(actual)}."
        f" Expected {expected_type}.",
        path,
    )


def unexpected_value(
    actual_value, expected_values: List[Any], path: _Optional[str]
) -> InvalidSchema:
    if path is None:
        return InvalidSchema(
            f"The value is {actual_value}. Expected one of {expected_values}", path
        )
    else:
        return InvalidSchema(
            f"The value of '{path}' is {actual_value}. Expected one of {expected_values}.",
            path,
        )


def build_path(path: _Optional[str], key: str) -> str:
    if isinstance(key, Optional):
        key = key.key

    if path is None:
        return key
    return f"{path}.{key}"


def build_index_path(path: _Optional[str], index: int) -> str:
    if not path:
        return f"[{index}]"
    return path + f"[{index}]"


class TypeOf:
    def __init__(self, expected_type: Type):
        self.expected = expected_type

    def validate(
        self, actual: Any, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        is_valid = isinstance(actual, self.expected)
        if is_valid:
            return is_valid, None
        else:
            return is_valid, unexpected_type(
                actual,
                self.expected,
                path,
            )

    def __repr__(self) -> str:
        return f"TypeOf({self.expected})"


class ListOf(TypeOf):
    def __init__(self, expected: Any):
        if not isinstance(expected, TypeOf):
            expected = TypeOf(expected)
        super().__init__(expected)

    def validate(
        self, actual: Any, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        if not isinstance(actual, list):
            return False, unexpected_type(actual, list, path)

        else:
            is_valid = True
            invalid_schema = None
            for index, item in enumerate(actual):
                is_valid, invalid_schema = self.expected.validate(
                    item, build_index_path(path, index)
                )
                if not is_valid:
                    break
            return is_valid, invalid_schema

    def __repr__(self) -> str:
        return f"ListOf({self.expected})"


class TypeOr(TypeOf):
    def __init__(self, *expected_types: Type):
        expected_types = [
            atype if isinstance(atype, TypeOf) else TypeOf(atype)
            for atype in expected_types
        ]
        super().__init__(expected_types)

    def validate(
        self, actual: Any, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        is_valid = False
        invalid_schema = None
        for expected_type in self.expected:
            is_valid, invalid_schema = expected_type.validate(actual, path)
            if is_valid:
                break

        if not is_valid:
            invalid_schema = unexpected_typeor(actual, self.expected, path)

        return is_valid, invalid_schema

    def __repr__(self) -> str:
        return f"TypeOr({self.expected})"


class Values(TypeOf):
    def __init__(self, *values: Any):
        self.expected = values

    def validate(
        self, actual: Any, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        if actual in self.expected:
            return True, None
        else:
            return False, unexpected_value(actual, self.expected, path)

    def __repr__(self) -> str:
        return f"Values({self.expected})"


class Optional(TypeOf):
    """Shorthand for TypeOr(type(None), X)"""

    def __init__(self, expected: Type):
        super().__init__(expected)
        self.typeor = TypeOr(type(None), expected)

    def validate(
        self, actual: Any, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        return self.typeor.validate(actual, path)

    def __repr__(self) -> str:
        return f"Optional({self.expected})"


class OptionalKey:
    """Mark a key in a Schema as optional. This allows not providing the key."""

    def __init__(self, key):
        self.key = key

    def __hash__(self):
        return hash(self.key)

    def __repr__(self):
        return f"OptionalKey({self.key})"

    def __eq__(self, key):
        return getattr(key, "key", key) == self.key


class Schema(TypeOf):
    def __init__(self, schema: dict):
        for value in schema.values():
            if isinstance(value, dict):
                raise TypeError("A schema should be a flat dictionary.")

        self.schema = {
            key: value if isinstance(value, TypeOf) else TypeOf(value)
            for key, value in schema.items()
        }

    def validate(
        self, actual, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        if not isinstance(actual, dict):
            return False, unexpected_type(actual, dict, path)

        for key in self.schema.keys():
            if key not in actual and not isinstance(key, OptionalKey):
                return False, missing_key(build_path(path, key))

        for key in actual.keys():
            if key not in self.schema:
                return False, unexpected_key(build_path(path, key))

        for key, expected_type in self.schema.items():
            # unwrap optional key
            if isinstance(key, OptionalKey):
                key = key.key

            # skip optional keys
            if key not in actual:
                continue

            is_valid, invalid_schema = expected_type.validate(
                actual[key], path=build_path(path, key)
            )
            if not is_valid:
                return is_valid, invalid_schema

        return True, None

    def __repr__(self):
        assignments = ", ".join(
            [f"{key}={value}" for key, value in self.schema.items()]
        )
        return f"Schema({assignments})"


class DictOf(TypeOf):
    def __init__(self, key_type: Type, value_type: Type, allow_empty: bool = True):
        if isinstance(key_type, (DictOf, Schema, Optional, OptionalKey)):
            raise TypeError(
                "DictOf, Schema, Optional and OptionalKey are not allowed as key types."
            )

        if not isinstance(key_type, TypeOf):
            key_type = TypeOf(key_type)

        if not isinstance(value_type, TypeOf):
            value_type = TypeOf(value_type)

        self.key_type = key_type
        self.value_type = value_type
        self.allow_empty = allow_empty

    def validate(
        self, actual: Any, path: _Optional[str] = None
    ) -> Tuple[bool, _Optional[InvalidSchema]]:
        if not isinstance(actual, dict):
            return False, unexpected_type(actual, dict, path)

        if not self.allow_empty and len(actual) == 0:
            return False, empty_dict(path)

        for key, value in actual.items():
            is_valid_key, _ = self.key_type.validate(key)
            if not is_valid_key:
                return False, unexpected_key_type(
                    key, self.key_type, build_path(path, str(key))
                )

            is_valid, invalid_schema = self.value_type.validate(
                actual[key], build_path(path, str(key))
            )
            if not is_valid:
                return False, invalid_schema

        return True, None
