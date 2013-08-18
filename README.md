## smartest.vim

Make your Vim smart when running your tests.

In your **Rails** project with `RSpec`, it'll run the current test file the
fastest way possible:

* Runs current file with `Spring` gem if you have it running, or
* Runs current file with `zeus` if you have it running, or
* Runs `bundle exec rspec $current_file` if current test file has
`spec_helper`, `acceptance_spec_helper` etc anywhere in the current file (which
means it needs `bundle exec`), or
* uses pure RSpec (no `bundle exec`) other wise. This is useful for people like
me that don't like running specs with Bundler when it's not needed.

In your **Ruby** project using minitest, it:

* when in the Rails project, you need to add the current framework
(e.g `actionview`, `activerecord`) as dependency (e.g `-Iactionview/lib`),
so if you in an `actionview` file, it'll run
`ruby -Iactionview/lib:actionview/test $current_file`, or
* Runs `ruby -Ilib $current_file`

If you're testing Javascript, smartest:

* checks if it's a Konacha spec and runs it using zeus or bundler
(whichever is available).
* runs `rake` if it doesn't know what to do (e.g `QUnit`)

### Usage

`smartest.vim` doesn't map any key, so these are the mappings I use and recommend:

    map <leader>t :call RunTestFile()<cr>
    map <leader>r :call RunNearestTest()<cr>

Here, `<leader>t` would run all tests in the current file,
while `<leader>r` would run only the test under the cursor.

### Bonus feature 1

If your test file **user_spec.rb** and runs `<leader>t` (considering the mappings above),
it'll run it. If you go to file **user.rb** (not a test file) and runs `<leader>t`
again, it'll run the last test file run (idea by Gary Bernhardt).

This means you don't need to have your test file buffer opened to run it. You
can just code and call the tests.

### Bonus feature 2

If you use `RunNearestTest()`, which is `<leader>r` for me, it'll run only the
test under the cursor, even on **Minitest**.


## License

MIT.

## Author

Alexandre de Oliveira, at http://github.com/kurko
