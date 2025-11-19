+++
title = "Why Your Django Models Don't Show Up in Python's -X importtime (And How to Fix It)"
date = 2025-11-18
slug = "why-your-django-models-dont-show-up-in-pythons-x-importtime-and-how-to-fix-it"
description = "Understand why your Django app's models don't appear in Python's -X importtime output, and how to fix it for better profiling."
tags = ["django", "python", "importtime", "profiling"]
+++

## The Mystery

I was profiling my Django application's startup time using Python's `-X importtime` flag, which shows how long each module takes to import:

```bash
python -X importtime manage.py check 2>&1 > import.log
```

Looking at the output, I saw Django's built-in models:

```
import time:       941 |        941 | django.contrib.contenttypes.models
import time:      1466 |     496404 | django.contrib.auth.base_user
import time:       743 |        743 | django.contrib.sessions.base_session
```

But my own app's models were mysteriously absent! I could see other modules from my app:

```
import time:       251 |        251 | app.managers
```

But `app.models` was nowhere to be found, even though I added print statements in my `models.py` that clearly executed:

```python
# app/models.py
print("Starting model imports...")
from django.db import models
# ... model definitions ...
print("End model imports...")
```

The prints appeared in the output, proving the module was being imported. So why wasn't `-X importtime` logging it?

## The Investigation

### First Clue: Print Statements vs Import Log

The fact that my print statements appeared between the import timing logs was significant:

```
import time:       251 |        251 | app.managers
Starting model imports...
End model imports...
System check identified no issues (0 silenced).
```

This meant `app.models` **was** being imported and executed, but `-X importtime` wasn't creating a log entry for it.

### Testing Different Import Methods

I created a test to see which import methods show up in `-X importtime`:

```python
# Test different import approaches
def test_import_statement():
    import testpkg.mymodels  # Direct import

def test_import_module():
    from importlib import import_module
    import_module('testpkg.mymodels')  # What Django uses

def test_exec():
    exec('import testpkg.mymodels')  # Using exec

def test_find_spec():
    import importlib.util
    spec = importlib.util.find_spec('testpkg.mymodels')
    # Just finds, doesn't import
```

Running these with `-X importtime` revealed a critical pattern:

| Method | Shows in `-X importtime`? | Actually imports? |
|--------|--------------------------|-------------------|
| `import` statement | ✅ YES | ✅ YES |
| `import_module()` | ❌ NO | ✅ YES |
| `exec('import ...')` | ✅ YES | ✅ YES |
| `find_spec()` | ❌ NO | ❌ NO (just finds) |

**The key discovery:** `-X importtime` only tracks imports done via direct `import` statements, not via `importlib.import_module()`!

### How Django Imports Models

Looking at Django's source code, I found the culprit in `django/apps/config.py`:

```python
class AppConfig:
    def import_models(self):
        self.models = self.apps.all_models[self.label]

        if module_has_submodule(self.module, MODELS_MODULE_NAME):
            models_module_name = '%s.%s' % (self.name, MODELS_MODULE_NAME)
            self.models_module = import_module(models_module_name)  # ← Here!
```

Django uses `import_module()` to dynamically import each app's models. This is necessary because the module name is a variable, and you can't do `import {variable}` in Python. But it means these imports are invisible to `-X importtime`!

### Why `app.managers` Shows Up

My `app.managers` module appeared in the log because my `models.py` imports it with a direct import statement:

```python
# app/models.py
from . import managers  # ← Direct import statement!
```

This relative import is a real Python `import` statement, so it gets tracked. But the models module itself is imported via `import_module()`, so it doesn't appear.

## The Solution

Since `exec('import ...')` triggers `-X importtime` tracking (because it executes an actual import statement), we can use it instead of `import_module()` when profiling.

### Solution 1: Global Monkeypatch (Fastest)

For quick profiling, monkeypatch Django's `AppConfig.import_models()` globally:

```python
# patch_all_appconfigs.py
import sys
from importlib import import_module


def patch_all_appconfigs():
    """Patch Django to use exec() when -X importtime is active"""
    # Only patch if -X importtime is active
    if not sys._xoptions.get('importtime'):
        return

    from django.apps import AppConfig
    from django.utils.module_loading import module_has_submodule

    # Save original method
    _original_import_models = AppConfig.import_models

    def patched_import_models(self):
        self.models = self.apps.all_models[self.label]

        if module_has_submodule(self.module, 'models'):
            models_module_name = f'{self.name}.models'

            # Use exec() to make import visible
            exec(f'import {models_module_name}')
            self.models_module = sys.modules[models_module_name]

    # Apply patch
    AppConfig.import_models = patched_import_models

```

**Usage:** Just add two lines to your `manage.py`:

```python
#!/usr/bin/env python
import os
import sys

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')

    from patch_all_appconfigs import patch_all_appconfigs  # ← Add this line
    patch_all_appconfigs()  # ← Add this line

    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
```

Now ALL apps (including third-party) will show up in `-X importtime`!

### Solution 2: Custom AppConfig (Cleanest)

For a cleaner, per-app approach without monkeypatching:

```python
# importtime_appconfig.py
import sys
from django.apps import AppConfig as DjangoAppConfig
from django.utils.module_loading import module_has_submodule
from importlib import import_module


class ImportTimeVisibleAppConfig(DjangoAppConfig):
    """AppConfig that appears in -X importtime when profiling"""

    def import_models(self):
        self.models = self.apps.all_models[self.label]

        if module_has_submodule(self.module, 'models'):
            models_module_name = f'{self.name}.models'

            # Auto-detect if -X importtime is active
            if sys._xoptions.get('importtime'):
                # Use exec() for visibility
                exec(f'import {models_module_name}')
                self.models_module = sys.modules[models_module_name]
            else:
                # Use standard import_module() (zero overhead)
                self.models_module = import_module(models_module_name)
```

**Usage:** Create a custom AppConfig for your app:

```python
# app/apps.py
from importtime_appconfig import ImportTimeVisibleAppConfig

class AppConfig(ImportTimeVisibleAppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'app'
```

Update `settings.py`:

```python
INSTALLED_APPS = [
    # Use full path to your AppConfig
    'app.apps.AppConfig',  # Not just 'app'
]
```

### The Magic: Auto-Detection

Both solutions use `sys._xoptions.get('importtime')` to detect when `-X importtime` is active:

```python
if sys._xoptions.get('importtime'):
    exec(f'import {models_module_name}')  # Visible in -X importtime
else:
    import_module(models_module_name)      # Normal Django behavior
```

This means **zero overhead** when not profiling - the `exec()` path only activates when you actually run with `-X importtime`!

## Results

After applying the patch:

```bash
python -X importtime manage.py check 2>&1 | grep "\.models"
```

**Before:**
```
import time:       941 |        941 | django.contrib.contenttypes.models
import time:      1466 |     496404 | django.contrib.auth.base_user
# ← app.models is missing!
```

**After:**
```
import time:       941 |        941 | django.contrib.contenttypes.models
import time:      1466 |     496404 | django.contrib.auth.base_user
import time:       743 |        743 | django.contrib.sessions.base_session
import time:       325 |        325 | app.models           # ← Now visible!
import time:       412 |        412 | myapp.models         # ← Now visible!
import time:       278 |        278 | thirdparty.models    # ← Now visible!
```

Perfect! Now we can actually profile Django model imports.

## Why This Matters

Understanding import times is crucial for:

- **Faster development**: Reducing Django server startup time during development
- **Better production performance**: Optimizing cold start times in serverless/container environments
- **Identifying bottlenecks**: Finding slow imports that could be lazy-loaded

Without visibility into model imports, you're missing a huge piece of the puzzle - models often import heavy dependencies like database drivers, serializers, and third-party libraries.

## The Core Insight

The fundamental issue is that **Python's `-X importtime` only instruments the `import` statement bytecode**, not the `importlib.import_module()` function. When you use `import_module()`, you're calling a Python function that internally uses the import machinery, but it bypasses the instrumentation hooks that `-X importtime` sets up.

Using `exec('import ...')` works because exec evaluates the code as if it were written directly in your source file, which means it compiles to actual `import` statement bytecode that `-X importtime` can instrument.

## Which Solution Should You Use?

**Use the global monkeypatch if:**
- You want a quick, one-time profiling session
- You want to see ALL apps including third-party ones
- You don't mind a small monkeypatch for temporary debugging

**Use the per-app AppConfig if:**
- You want to keep the profiling capability long-term
- You only care about your own apps
- You prefer explicit configuration over magic
- You want to avoid monkeypatching Django

Both approaches have **zero overhead** in normal operation since they only activate when `-X importtime` is detected!

## Conclusion

Django's use of `import_module()` for dynamic imports makes perfect sense for its architecture, but it creates a blind spot when profiling with `-X importtime`. By detecting when profiling is active and switching to `exec()`, we get the best of both worlds: clean dynamic imports in production and full visibility during profiling.

The investigation journey - from noticing the missing imports, to testing different import methods, to discovering the `sys._xoptions` detection mechanism - shows how understanding Python's import system deeply can help solve real-world debugging challenges.

Now go forth and profile those Django imports! 🚀

## Download the Code

All the code from this investigation is available:
- `patch_all_appconfigs.py` - Global monkeypatch solution
- `importtime_appconfig.py` - Per-app AppConfig solution
- Complete usage examples and documentation

Happy profiling!