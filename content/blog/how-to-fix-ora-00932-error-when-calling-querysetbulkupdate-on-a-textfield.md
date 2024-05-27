+++
title = "How to fix ORA-00932 error when calling QuerySet.bulk_update on a TextField"
date = "2024-05-26T14:22:18-06:00"

#
# description is optional
#
# description = "An optional description for SEO. If not provided, an automatically created summary will be used."

tags = ["Django", "Oracle", ]
+++

## Intro

Django's [`bulk_update`](https://docs.djangoproject.com/en/4.2/ref/models/querysets/#bulk-update) QuerySet method allows you to update multiple objects in a single SQL `UPDATE` statement. I recently ran into an issue calling `bulk_update` against an Oracle database, and in this post, I will share the solution I used to fix it.

The Oracle error that we'll be fixing is this:

```sql
ORA-00932: inconsistent datatypes: expected CHAR got CLOB
```

## Background

First, let's start with an example Django model `Throwaway` with a single `TextField` named `my_field`:

```python
class Throwaway(models.Model):
    my_field = models.TextField(blank=True, null=True)
```

This error only occurs with `models.TextField`s, which gets created as an `NCLOB` in Oracle.

To demonstrate the error, let's create some `Throwaway` objects in the database:

```python
a = Throwaway.objects.create(text="a")
b = Throwaway.objects.create(text="b")
```

Now we'll call `bulk_update` with values that will cause the ORA-00932 error to occur. First, we need to make changes to the `my_field` field:

```python
a.my_field = "a" * 10    # must be less than 4,000
b.my_field = "b" * 4005  # must be greater than 4,000
```

Then we'll call `bulk_update` to save these changes. Remember that the first `bulk_update` argument is a collection of Django model instances (it can be a `QuerySet`, a `list` or a `tuple`). The second argument is a list of field names that will be updated.

```python
Throwaway.objects.bulk_update([a, b], ["my_field"])
```

This will raise a `DatabaseError` exception:

```python
django.db.utils.DatabaseError: ORA-00932: inconsistent datatypes: expected CHAR got CLOB
```

## Solution

To fix this, we need to update the `Throwaway` objects where `my_field` is greater than `4000` characters long _separately_ from the `Throwaway` objects where `my_field` is less than or equal to `4000` characters in length.

```python
objs = [a, b]
clob_updates = []
char_updates = []

for obj in objs:
    if len(obj.my_field) > 4000:
        clob_updates.append(obj)
    else:
        char_updates.append(obj)

Throwaway.objects.bulk_update(clob_updates, ["my_field"])
Throwaway.objects.bulk_update(char_updates, ["my_field"])
```

## Cause

The cause of this issue is the fact that, when you run an `UPDATE` statement in Oracle, each new value that is passed into the `UPDATE` statement must be of the same type. For example, if you're updating a `NUMBER` column, every updated value you provide in the `UPDATE` statement must be a `NUMBER`. You can't mix and match types.

However, when we try to update the `Throwaway.my_field` values in the example above, if some of the new `my_field` values are <=4000 characters long and others are >4000 characters long, Oracle tries to use `CHAR`s and `CLOB`s in a single `UPDATE` statement. This illegal mixing of types is what Oracle refers to when the error says "inconsistent datatypes: expected CHAR got CLOB".
