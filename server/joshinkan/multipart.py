import re
from typing import Union, Optional


def parse(body: str, content_type: str) -> Optional[dict[str, Union[str, list[str]]]]:
    boundary_pattern = re.compile(
        r"^multipart\/form-data;\s*boundary=(?P<boundary>.+)$"
    )
    name_pattern = re.compile(r'^form-data;\s?name\s?=\s?"(?P<name>.+)"$')

    parsed_content_type = boundary_pattern.match(content_type)

    if parsed_content_type is None:
        raise ValueError("Could not parse 'boundary' from content_type")

    boundary = parsed_content_type.group("boundary")
    if boundary is None:
        raise ValueError("Could not parse 'boundary' from content_type")

    components = [
        component
        for component in (
            component.strip() for component in body.split("--" + boundary)
        )
        if component != ""
    ]
    if len(components) < 2:
        raise ValueError(f"Boundary not found in body: {boundary}")
    if components[-1] != "--":
        raise ValueError("Invalid end boundary")

    form_data = {}

    # NOTE(sven): Skip the the last component which are double hyphens.
    for i in range(len(components) - 1):
        component = components[i]
        parts = component.splitlines()
        headers = {}

        for part_index, header_line in enumerate(parts):
            if header_line == "":
                break
            try:
                key, value = header_line.split(":", maxsplit=1)
            except ValueError:
                raise ValueError(
                    f"Part {i} does not specify content disposition header"
                )
            headers[key.casefold()] = value.strip()
        part_index += 1

        if "content-disposition" not in headers:
            raise ValueError(f"Part {i} does not specify content disposition header")

        # i.e. form-data; name=\"first_name\"
        parsed_name = name_pattern.match(headers["content-disposition"])
        assert (
            parsed_name is not None
        ), f"Could not parse name from content-disposition header: {headers['content-disposition']}"

        name = parsed_name.group("name")
        assert (
            name is not None
        ), f"Could not parse name from content-disposition header: {headers['content-disposition']}"
        name = name.strip()

        # TODO(sven): This potentially erases bespoke linebreaks from the
        # content. I don't see a usecase yet but this is something to be aware
        # of.
        part_body = "\n".join(parts[part_index:])

        if name.endswith("[]"):
            stripped_name = name.rstrip("[]")
            if stripped_name not in form_data:
                form_data[stripped_name] = []
            form_data[stripped_name].append(part_body)
        else:
            form_data[name] = part_body

    return form_data
