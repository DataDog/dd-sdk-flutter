# Flag selection vectors

`selection-vectors.json` is an unmodified copy of `flag-selection/selection-vectors.json` from
[DataDog/ffe-system-test-data](https://github.com/DataDog/ffe-system-test-data) at commit
`29ba6bf2e7514cf1b75c046b8956a22565221ee8` (blob `2daf24b92766f9228e9b469b26f17dcc6b63c50f`).

`selection_vectors.dart` holds the same vectors as a Dart constant, because tests on the web platform
cannot read files. `flag_selection_fixture_test.dart` fails when the two differ. To update, copy the
file from a newer commit, update the commit above, and regenerate the constant from this directory:

```bash
python3 - <<'PY'
import json
data = json.load(open('selection-vectors.json'))
body = json.dumps(data, ensure_ascii=True, indent=2)
header = open('selection_vectors.dart').read().split("r'''")[0]
open('selection_vectors.dart', 'w').write(header + "r'''\n" + body + "\n''';\n")
PY
```
