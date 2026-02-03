+++
title = "How to Specify a Structured Output Response Format in Geminis Batch Predictions API"
date = "2025-03-11T10:11:23-06:00"
slug = "how-to-specify-a-structured-output-response-format-in-geminis-batch-predictions-api"

#
# description is optional
#
# description = "An optional description for SEO. If not provided, an automatically created summary will be used."

tags = ["pydantic","json schema","gemini","google"]
+++

In my [previous post](/jonesnc/how-to-specify-a-structured-output-response-format-in-openais-batch-api/), I described how to use Structured Output with OpenAI's Batch API.

In this post, my goal is to document the same thing for Google's Gemini models. The goal is to instruct Google's Batch Predictions APIs to structure its text responses as valid JSON data that adheres to a given JSON Schema or Pdyantic model. I couldn't find this particular configuration anywhere in Google documentation, so I wanted to share it. I recommend reading my [previous post](/jonesnc/how-to-specify-a-structured-output-response-format-in-openais-batch-api/) first if you haven't already, as that covers a lot of the basic concepts related to these APIs.

I will also demonstrate here how to embed request metadata in the `labels` data, which can helpful when storing the results in a database.

Given this `Result` Pydantic class:

```python
class Result(BaseModel, extra="allow"):
    """Prediction result example.""""

    # allow numbers 0-10
    num_example: int = Field(..., ge=0, le=10)
    str_example: str
```

Each line in the input `.jsonl` file should have this structure:

```python
jsonl_line = {
    "request": {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": "# Your prompt message."}
                ]
            }
        ],
        "system_instruction": {
            "parts": [
                {
                    "text": "# Your system prompt message."
                }
            ]
        },
        "labels": {
            # Metadata about the request can be embedded here as a JSON string.
            "metadata": json.dumps({
                "key1": "value1",
                "key2": "value2"
            })
        },
        "generation_config": {
            # .model_json_schema() converts the Pydantic model
            # to JSON schema
            "response_schema": Result.model_json_schema(),

            "response_mime_type": "application/json",

            # Optional, but it can be helpful for ensuring
            # JSON-parseable responses
            "temperature": 0.5
        }
    }
}
```

