+++
title = "How to specify a Structured Output Response Format in OpenAI's Batch API"
date = "2025-01-13"

tags = ["OpenAI", "JSON Schema"]
+++

## Problem

I recently started using OpenAI's [Batch API](https://platform.openai.com/docs/guides/batch) to send multiple jobs to OpenAI, and for the most part it's been a pretty smooth experience. However, it was difficult to figure out how to get the batch results to adhere to a consistent data structure. While OpenAI has provided a way to [ensure a response adheres to a JSON Schema for a single job response](https://platform.openai.com/docs/guides/structured-outputs), the documentation for the Batch API doesn't explain how to get Structured Output from a batch job's series of responses.

This blog post explains and provides an example of how to specify a JSON Schema that a batch job's responses must adhere to.

Ensuring response data is useful because it allows you to store the resulting data in a structured environment like a database table.

---

NOTE: the `.jsonl` files shown in this post is reformatted to improve readability. In order to actually use it in a `.jsonl` file, it would need to be compacted back onto a single line.

## Solution


Let's start with the `.jsonl` example from the [OpenAI Batch API Guide](https://platform.openai.com/docs/guides/batch?lang=python#1-preparing-your-batch-file):

```json
{
    "custom_id": "request-1",
    "method": "POST",
    "url": "/v1/chat/completions",
    "body": {
        "model": "gpt-3.5-turbo-0125",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": "Hello world!"
            }
        ],
        "max_tokens": 1000
    }
}
```

To specify the JSON Schema of the response format for this message, add a `response_format` object within the existing `body` object of the `.jsonl` line:

```json
{
    "custom_id": "request-1",
    "method": "POST",
    "url": "/v1/chat/completions",
    "body": {
        "model": "gpt-3.5-turbo-0125",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": "Hello world!"
            }
        ],
        "max_tokens": 1000,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "a_json_schema",
                "schema": {
                    ...
                },
                "strict": true
            }
        }
    }
}
```

The `response_format.type` key must be set to the literal string `"json_schema"`. The `response_format.json_schema` object must include a `"name"` field whose value can be set to anything. The `struct` field is optional, and when set to `true`, it should tell OpenAI to not include any additional fields in the response that aren't specified in the JSON Schema.

The contents of the `response_format.json_schema.schema` object is where you include your JSON Schema definition that the job responses will adhere to. In my own Python project, I generated the JSON Schema from a Pydantic model, which can be done with the [`BaseModel.model_json_schema`](https://docs.pydantic.dev/latest/concepts/json_schema/#generating-json-schema) function.

---

A full `.jsonl` example that includes a simple [Person JSON Schema](https://json-schema.org/learn/miscellaneous-examples) in the `response_format` is shown below:

```json
{
    "custom_id": "request-1",
    "method": "POST",
    "url": "/v1/chat/completions",
    "body": {
        "model": "gpt-3.5-turbo-0125",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": "Hello world!"
            }
        ],
        "max_tokens": 1000,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "person_json_schema",
                "schema": {
                    "$id": "https://example.com/person.schema.json",
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "title": "Person",
                    "type": "object",
                    "properties": {
                        "firstName": {
                            "type": "string",
                            "description": "The person's first name."
                        },
                        "lastName": {
                            "type": "string",
                            "description": "The person's last name."
                        },
                        "age": {
                            "description": "Age in years which must be equal to or greater than zero.",
                            "type": "integer",
                            "minimum": 0
                        }
                    }
                },
                "strict": true
            }
        }
    }
}
```

And you're done! This method has worked well for me so far.

## References

- [Structured Outputs with Batch Processing](https://community.openai.com/t/structured-outputs-with-batch-processing/911076/4)
- [Batch API](https://platform.openai.com/docs/guides/batch)
- [Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs)
