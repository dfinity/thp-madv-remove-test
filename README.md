Minimal reproducer for a potential kernel regression where
`madvise(MADV_REMOVE)` on a 4KiB range within a huge-page-backed
`MAP_SHARED` memfd region corrupts nearby pages.

Run the `thp-madv-remove-test` rust binary in a VM running linux-6.17:
```
$ nix build .#checks.x86_64-linux.test_6_17 -L
```

Run the `thp-madv-remove-test` rust binary in a VM running linux-6.18:
```
$ nix build .#checks.x86_64-linux.test_6_18 -L
```