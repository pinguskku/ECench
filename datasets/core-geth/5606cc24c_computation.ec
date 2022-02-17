commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
commit 5606cc24c495daae63b0b1490f6c2643502c6455
Author: meows <b5c6@protonmail.com>
Date:   Wed Mar 24 15:13:05 2021 -0500

    tests: improve error handling
    
    Date: 2021-03-24 15:13:05-05:00
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/tests/state_mgen_test.go b/tests/state_mgen_test.go
index 9135281e5..17d4df6f7 100644
--- a/tests/state_mgen_test.go
+++ b/tests/state_mgen_test.go
@@ -143,9 +143,12 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 		t.Run(key, func(t *testing.T) {
 			withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
 				err := test.RunSetPost(subtest, vmconfig)
+				if err != nil {
+					t.Fatalf("Error encountered at RunSetPost: %v", err)
+				}
 
 				// Only write the test once, after all subtests have been written.
-				if err == nil && filledPostStates(test.json.Post[subtest.Fork]) {
+				if filledPostStates(test.json.Post[subtest.Fork]) {
 					b, err := json.MarshalIndent(test, "", "    ")
 					if err != nil {
 						return err
@@ -165,8 +168,6 @@ func withWritingTests(t *testing.T, name string, test *StateTest) {
 						panic(err)
 					}
 					t.Logf("Wrote test file: %s\n", fpath)
-				} else {
-					t.Errorf("Error encountered at RunSetPost: %v", err)
 				}
 				return nil
 			})
