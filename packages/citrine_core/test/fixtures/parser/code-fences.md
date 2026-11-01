# Code fence fixture

- [ ] Real task before the fence 📅 2026-08-01

```dart
- [ ] not a task, this is inside a fenced code block
[[not a link]]
#not-a-tag @not-a-context ^not-a-blockid
```

- [ ] Real task between fences

~~~
- [ ] also not a task (tilde fence)
~~~

Some prose with `- [ ] inline code is not fence-aware, out of scope for W2`.

````
- [ ] outer fence uses 4 backticks
```
- [ ] a line that looks like a 3-backtick fence, but we're still inside the
outer fence since it takes 4+ backticks to close
```
````

- [ ] Real task after all fences

```
unterminated fence: everything after this is code, including
- [ ] this line
[[this link]]
