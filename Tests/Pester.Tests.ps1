Describe "No test" {
    Context "Nothing" {
        It "Tests nothing" {

        }
    }
}

Describe "Fail test" {
    Context "Fail" {
        It "Fails" {
            1 | Should Be 0
        }
    }
}
