commit 8f031cc85f6e56a6e9920a5c95e6dc2861472863
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Mon Jun 1 14:16:17 2020 +0200

    Update Secp256k1 and tune its flags for performance (#600)
    
    * Update to https://github.com/bitcoin-core/secp256k1/commit/05d315affe0acd02591c8db783ce1badb0c37a31
    
    * Changes in the wrapper after the library upgrade
    
    * Faster config for x64
    
    * USE_ENDOMORPHISM

diff --git a/crypto/secp256k1/ext.h b/crypto/secp256k1/ext.h
index e422fe4b4..0d219e8b6 100644
--- a/crypto/secp256k1/ext.h
+++ b/crypto/secp256k1/ext.h
@@ -116,7 +116,7 @@ int secp256k1_ext_scalar_mul(const secp256k1_context* ctx, unsigned char *point,
 	if (overflow || secp256k1_scalar_is_zero(&s)) {
 		ret = 0;
 	} else {
-		secp256k1_ecmult_const(&res, &ge, &s);
+		secp256k1_ecmult_const(&res, &ge, &s, 256);
 		secp256k1_ge_set_gej(&ge, &res);
 		/* Note: can't use secp256k1_pubkey_save here because it is not constant time. */
 		secp256k1_fe_normalize(&ge.x);
diff --git a/crypto/secp256k1/libsecp256k1/.gitignore b/crypto/secp256k1/libsecp256k1/.gitignore
index 87fea161b..cb4331aa9 100644
--- a/crypto/secp256k1/libsecp256k1/.gitignore
+++ b/crypto/secp256k1/libsecp256k1/.gitignore
@@ -1,5 +1,6 @@
 bench_inv
 bench_ecdh
+bench_ecmult
 bench_sign
 bench_verify
 bench_schnorr_verify
@@ -8,6 +9,7 @@ bench_internal
 tests
 exhaustive_tests
 gen_context
+valgrind_ctime_test
 *.exe
 *.so
 *.a
diff --git a/crypto/secp256k1/libsecp256k1/.travis.yml b/crypto/secp256k1/libsecp256k1/.travis.yml
index 243952924..a6ad6fb27 100644
--- a/crypto/secp256k1/libsecp256k1/.travis.yml
+++ b/crypto/secp256k1/libsecp256k1/.travis.yml
@@ -1,18 +1,23 @@
 language: c
-sudo: false
+os:
+  - linux
+  - osx
+
+dist: bionic
+# Valgrind currently supports upto macOS 10.13, the latest xcode of that version is 10.1
+osx_image: xcode10.1
 addons:
   apt:
-    packages: libgmp-dev
+    packages:
+      - libgmp-dev
+      - valgrind
+      - libtool-bin
 compiler:
   - clang
   - gcc
-cache:
-  directories:
-  - src/java/guava/
 env:
   global:
-    - FIELD=auto  BIGNUM=auto  SCALAR=auto  ENDOMORPHISM=no  STATICPRECOMPUTATION=yes  ASM=no  BUILD=check  EXTRAFLAGS=  HOST=  ECDH=no  RECOVERY=no  EXPERIMENTAL=no
-    - GUAVA_URL=https://search.maven.org/remotecontent?filepath=com/google/guava/guava/18.0/guava-18.0.jar GUAVA_JAR=src/java/guava/guava-18.0.jar
+    - FIELD=auto  BIGNUM=auto  SCALAR=auto  ENDOMORPHISM=no  STATICPRECOMPUTATION=yes  ECMULTGENPRECISION=auto  ASM=no  BUILD=check  EXTRAFLAGS=  HOST=  ECDH=no  RECOVERY=no  EXPERIMENTAL=no CTIMETEST=yes BENCH=yes ITERS=2
   matrix:
     - SCALAR=32bit    RECOVERY=yes
     - SCALAR=32bit    FIELD=32bit       ECDH=yes  EXPERIMENTAL=yes
@@ -26,44 +31,78 @@ env:
     - BIGNUM=no
     - BIGNUM=no       ENDOMORPHISM=yes RECOVERY=yes EXPERIMENTAL=yes
     - BIGNUM=no       STATICPRECOMPUTATION=no
-    - BUILD=distcheck
-    - EXTRAFLAGS=CPPFLAGS=-DDETERMINISTIC
-    - EXTRAFLAGS=CFLAGS=-O0
-    - BUILD=check-java ECDH=yes EXPERIMENTAL=yes
+    - BUILD=distcheck CTIMETEST= BENCH=
+    - CPPFLAGS=-DDETERMINISTIC
+    - CFLAGS=-O0 CTIMETEST=
+    - ECMULTGENPRECISION=2
+    - ECMULTGENPRECISION=8
+    - VALGRIND=yes ENDOMORPHISM=yes BIGNUM=no ASM=x86_64 EXPERIMENTAL=yes ECDH=yes  RECOVERY=yes EXTRAFLAGS="--disable-openssl-tests" CPPFLAGS=-DVALGRIND BUILD=
+    - VALGRIND=yes                  BIGNUM=no ASM=x86_64 EXPERIMENTAL=yes ECDH=yes  RECOVERY=yes EXTRAFLAGS="--disable-openssl-tests" CPPFLAGS=-DVALGRIND BUILD=
 matrix:
   fast_finish: true
   include:
     - compiler: clang
+      os: linux
       env: HOST=i686-linux-gnu ENDOMORPHISM=yes
       addons:
         apt:
           packages:
             - gcc-multilib
             - libgmp-dev:i386
+            - valgrind
+            - libtool-bin
+            - libc6-dbg:i386
     - compiler: clang
       env: HOST=i686-linux-gnu
+      os: linux
       addons:
         apt:
           packages:
             - gcc-multilib
+            - valgrind
+            - libtool-bin
+            - libc6-dbg:i386
     - compiler: gcc
       env: HOST=i686-linux-gnu ENDOMORPHISM=yes
+      os: linux
       addons:
         apt:
           packages:
             - gcc-multilib
+            - valgrind
+            - libtool-bin
+            - libc6-dbg:i386
     - compiler: gcc
+      os: linux
       env: HOST=i686-linux-gnu
       addons:
         apt:
           packages:
             - gcc-multilib
             - libgmp-dev:i386
-before_install: mkdir -p `dirname $GUAVA_JAR`
-install: if [ ! -f $GUAVA_JAR ]; then wget $GUAVA_URL -O $GUAVA_JAR; fi
+            - valgrind
+            - libtool-bin
+            - libc6-dbg:i386
+
+# We use this to install macOS dependencies instead of the built in `homebrew` plugin,
+# because in xcode earlier than 11 they have a bug requiring updating the system which overall takes ~8 minutes.
+# https://travis-ci.community/t/macos-build-fails-because-of-homebrew-bundle-unknown-command/7296
+before_install:
+ - if [ "${TRAVIS_OS_NAME}" = "osx" ]; then HOMEBREW_NO_AUTO_UPDATE=1 brew install gmp valgrind gcc@9; fi
+
 before_script: ./autogen.sh
+
+# travis auto terminates jobs that go for 10 minutes without printing to stdout, but travis_wait doesn't work well with forking programs like valgrind (https://docs.travis-ci.com/user/common-build-problems/#build-times-out-because-no-output-was-received https://github.com/bitcoin-core/secp256k1/pull/750#issuecomment-623476860)
 script:
- - if [ -n "$HOST" ]; then export USE_HOST="--host=$HOST"; fi
- - if [ "x$HOST" = "xi686-linux-gnu" ]; then export CC="$CC -m32"; fi
- - ./configure --enable-experimental=$EXPERIMENTAL --enable-endomorphism=$ENDOMORPHISM --with-field=$FIELD --with-bignum=$BIGNUM --with-scalar=$SCALAR --enable-ecmult-static-precomputation=$STATICPRECOMPUTATION --enable-module-ecdh=$ECDH --enable-module-recovery=$RECOVERY $EXTRAFLAGS $USE_HOST && make -j2 $BUILD
-os: linux
+  - function keep_alive() { while true; do echo -en "\a"; sleep 60; done }
+  - keep_alive &
+  - ./contrib/travis.sh
+  - kill %keep_alive
+
+after_script:
+    - cat ./tests.log
+    - cat ./exhaustive_tests.log
+    - cat ./valgrind_ctime_test.log
+    - cat ./bench.log
+    - $CC --version
+    - valgrind --version
diff --git a/crypto/secp256k1/libsecp256k1/Makefile.am b/crypto/secp256k1/libsecp256k1/Makefile.am
index c071fbe27..d8c1c79e8 100644
--- a/crypto/secp256k1/libsecp256k1/Makefile.am
+++ b/crypto/secp256k1/libsecp256k1/Makefile.am
@@ -1,13 +1,8 @@
 ACLOCAL_AMFLAGS = -I build-aux/m4
 
 lib_LTLIBRARIES = libsecp256k1.la
-if USE_JNI
-JNI_LIB = libsecp256k1_jni.la
-noinst_LTLIBRARIES = $(JNI_LIB)
-else
-JNI_LIB =
-endif
 include_HEADERS = include/secp256k1.h
+include_HEADERS += include/secp256k1_preallocated.h
 noinst_HEADERS =
 noinst_HEADERS += src/scalar.h
 noinst_HEADERS += src/scalar_4x64.h
@@ -39,9 +34,9 @@ noinst_HEADERS += src/field_5x52.h
 noinst_HEADERS += src/field_5x52_impl.h
 noinst_HEADERS += src/field_5x52_int128_impl.h
 noinst_HEADERS += src/field_5x52_asm_impl.h
-noinst_HEADERS += src/java/org_bitcoin_NativeSecp256k1.h
-noinst_HEADERS += src/java/org_bitcoin_Secp256k1Context.h
 noinst_HEADERS += src/util.h
+noinst_HEADERS += src/scratch.h
+noinst_HEADERS += src/scratch_impl.h
 noinst_HEADERS += src/testrand.h
 noinst_HEADERS += src/testrand_impl.h
 noinst_HEADERS += src/hash.h
@@ -72,21 +67,27 @@ endif
 
 libsecp256k1_la_SOURCES = src/secp256k1.c
 libsecp256k1_la_CPPFLAGS = -DSECP256K1_BUILD -I$(top_srcdir)/include -I$(top_srcdir)/src $(SECP_INCLUDES)
-libsecp256k1_la_LIBADD = $(JNI_LIB) $(SECP_LIBS) $(COMMON_LIB)
+libsecp256k1_la_LIBADD = $(SECP_LIBS) $(COMMON_LIB)
 
-libsecp256k1_jni_la_SOURCES  = src/java/org_bitcoin_NativeSecp256k1.c src/java/org_bitcoin_Secp256k1Context.c
-libsecp256k1_jni_la_CPPFLAGS = -DSECP256K1_BUILD $(JNI_INCLUDES)
+if VALGRIND_ENABLED
+libsecp256k1_la_CPPFLAGS += -DVALGRIND
+endif
 
 noinst_PROGRAMS =
 if USE_BENCHMARK
-noinst_PROGRAMS += bench_verify bench_sign bench_internal
+noinst_PROGRAMS += bench_verify bench_sign bench_internal bench_ecmult
 bench_verify_SOURCES = src/bench_verify.c
 bench_verify_LDADD = libsecp256k1.la $(SECP_LIBS) $(SECP_TEST_LIBS) $(COMMON_LIB)
+# SECP_TEST_INCLUDES are only used here for CRYPTO_CPPFLAGS
+bench_verify_CPPFLAGS = -DSECP256K1_BUILD $(SECP_TEST_INCLUDES)
 bench_sign_SOURCES = src/bench_sign.c
 bench_sign_LDADD = libsecp256k1.la $(SECP_LIBS) $(SECP_TEST_LIBS) $(COMMON_LIB)
 bench_internal_SOURCES = src/bench_internal.c
 bench_internal_LDADD = $(SECP_LIBS) $(COMMON_LIB)
 bench_internal_CPPFLAGS = -DSECP256K1_BUILD $(SECP_INCLUDES)
+bench_ecmult_SOURCES = src/bench_ecmult.c
+bench_ecmult_LDADD = $(SECP_LIBS) $(COMMON_LIB)
+bench_ecmult_CPPFLAGS = -DSECP256K1_BUILD $(SECP_INCLUDES)
 endif
 
 TESTS =
@@ -94,6 +95,12 @@ if USE_TESTS
 noinst_PROGRAMS += tests
 tests_SOURCES = src/tests.c
 tests_CPPFLAGS = -DSECP256K1_BUILD -I$(top_srcdir)/src -I$(top_srcdir)/include $(SECP_INCLUDES) $(SECP_TEST_INCLUDES)
+if VALGRIND_ENABLED
+tests_CPPFLAGS += -DVALGRIND
+noinst_PROGRAMS += valgrind_ctime_test
+valgrind_ctime_test_SOURCES = src/valgrind_ctime_test.c
+valgrind_ctime_test_LDADD = libsecp256k1.la $(SECP_LIBS) $(SECP_TEST_LIBS) $(COMMON_LIB)
+endif
 if !ENABLE_COVERAGE
 tests_CPPFLAGS += -DVERIFY
 endif
@@ -109,64 +116,34 @@ exhaustive_tests_CPPFLAGS = -DSECP256K1_BUILD -I$(top_srcdir)/src $(SECP_INCLUDE
 if !ENABLE_COVERAGE
 exhaustive_tests_CPPFLAGS += -DVERIFY
 endif
-exhaustive_tests_LDADD = $(SECP_LIBS)
+exhaustive_tests_LDADD = $(SECP_LIBS) $(COMMON_LIB)
 exhaustive_tests_LDFLAGS = -static
 TESTS += exhaustive_tests
 endif
 
-JAVAROOT=src/java
-JAVAORG=org/bitcoin
-JAVA_GUAVA=$(srcdir)/$(JAVAROOT)/guava/guava-18.0.jar
-CLASSPATH_ENV=CLASSPATH=$(JAVA_GUAVA)
-JAVA_FILES= \
-  $(JAVAROOT)/$(JAVAORG)/NativeSecp256k1.java \
-  $(JAVAROOT)/$(JAVAORG)/NativeSecp256k1Test.java \
-  $(JAVAROOT)/$(JAVAORG)/NativeSecp256k1Util.java \
-  $(JAVAROOT)/$(JAVAORG)/Secp256k1Context.java
-
-if USE_JNI
-
-$(JAVA_GUAVA):
-	@echo Guava is missing. Fetch it via: \
-	wget https://search.maven.org/remotecontent?filepath=com/google/guava/guava/18.0/guava-18.0.jar -O $(@)
-	@false
-
-.stamp-java: $(JAVA_FILES)
-	@echo   Compiling $^
-	$(AM_V_at)$(CLASSPATH_ENV) javac $^
-	@touch $@
-
-if USE_TESTS
-
-check-java: libsecp256k1.la $(JAVA_GUAVA) .stamp-java
-	$(AM_V_at)java -Djava.library.path="./:./src:./src/.libs:.libs/" -cp "$(JAVA_GUAVA):$(JAVAROOT)" $(JAVAORG)/NativeSecp256k1Test
-
-endif
-endif
-
 if USE_ECMULT_STATIC_PRECOMPUTATION
-CPPFLAGS_FOR_BUILD +=-I$(top_srcdir)
-CFLAGS_FOR_BUILD += -Wall -Wextra -Wno-unused-function
+CPPFLAGS_FOR_BUILD +=-I$(top_srcdir) -I$(builddir)/src
 
 gen_context_OBJECTS = gen_context.o
 gen_context_BIN = gen_context$(BUILD_EXEEXT)
-gen_%.o: src/gen_%.c
+gen_%.o: src/gen_%.c src/libsecp256k1-config.h
 	$(CC_FOR_BUILD) $(CPPFLAGS_FOR_BUILD) $(CFLAGS_FOR_BUILD) -c $< -o $@
 
 $(gen_context_BIN): $(gen_context_OBJECTS)
-	$(CC_FOR_BUILD) $^ -o $@
+	$(CC_FOR_BUILD) $(CFLAGS_FOR_BUILD) $(LDFLAGS_FOR_BUILD) $^ -o $@
 
 $(libsecp256k1_la_OBJECTS): src/ecmult_static_context.h
 $(tests_OBJECTS): src/ecmult_static_context.h
 $(bench_internal_OBJECTS): src/ecmult_static_context.h
+$(bench_ecmult_OBJECTS): src/ecmult_static_context.h
 
 src/ecmult_static_context.h: $(gen_context_BIN)
 	./$(gen_context_BIN)
 
-CLEANFILES = $(gen_context_BIN) src/ecmult_static_context.h $(JAVAROOT)/$(JAVAORG)/*.class .stamp-java
+CLEANFILES = $(gen_context_BIN) src/ecmult_static_context.h
 endif
 
-EXTRA_DIST = autogen.sh src/gen_context.c src/basic-config.h $(JAVA_FILES)
+EXTRA_DIST = autogen.sh src/gen_context.c src/basic-config.h
 
 if ENABLE_MODULE_ECDH
 include src/modules/ecdh/Makefile.am.include
diff --git a/crypto/secp256k1/libsecp256k1/README.md b/crypto/secp256k1/libsecp256k1/README.md
index 8cd344ea8..434178b37 100644
--- a/crypto/secp256k1/libsecp256k1/README.md
+++ b/crypto/secp256k1/libsecp256k1/README.md
@@ -3,17 +3,22 @@ libsecp256k1
 
 [![Build Status](https://travis-ci.org/bitcoin-core/secp256k1.svg?branch=master)](https://travis-ci.org/bitcoin-core/secp256k1)
 
-Optimized C library for EC operations on curve secp256k1.
+Optimized C library for ECDSA signatures and secret/public key operations on curve secp256k1.
 
-This library is a work in progress and is being used to research best practices. Use at your own risk.
+This library is intended to be the highest quality publicly available library for cryptography on the secp256k1 curve. However, the primary focus of its development has been for usage in the Bitcoin system and usage unlike Bitcoin's may be less well tested, verified, or suffer from a less well thought out interface. Correct usage requires some care and consideration that the library is fit for your application's purpose.
 
 Features:
 * secp256k1 ECDSA signing/verification and key generation.
-* Adding/multiplying private/public keys.
-* Serialization/parsing of private keys, public keys, signatures.
-* Constant time, constant memory access signing and pubkey generation.
-* Derandomized DSA (via RFC6979 or with a caller provided function.)
+* Additive and multiplicative tweaking of secret/public keys.
+* Serialization/parsing of secret keys, public keys, signatures.
+* Constant time, constant memory access signing and public key generation.
+* Derandomized ECDSA (via RFC6979 or with a caller provided function.)
 * Very efficient implementation.
+* Suitable for embedded systems.
+* Optional module for public key recovery.
+* Optional module for ECDH key exchange (experimental).
+
+Experimental features have not received enough scrutiny to satisfy the standard of quality of this library but are made available for testing and review by the community. The APIs of these features should not be considered stable.
 
 Implementation details
 ----------------------
@@ -23,11 +28,12 @@ Implementation details
   * Extensive testing infrastructure.
   * Structured to facilitate review and analysis.
   * Intended to be portable to any system with a C89 compiler and uint64_t support.
+  * No use of floating types.
   * Expose only higher level interfaces to minimize the API surface and improve application security. ("Be difficult to use insecurely.")
 * Field operations
   * Optimized implementation of arithmetic modulo the curve's field size (2^256 - 0x1000003D1).
     * Using 5 52-bit limbs (including hand-optimized assembly for x86_64, by Diederik Huys).
-    * Using 10 26-bit limbs.
+    * Using 10 26-bit limbs (including hand-optimized assembly for 32-bit ARM, by Wladimir J. van der Laan).
   * Field inverses and square roots using a sliding window over blocks of 1s (by Peter Dettman).
 * Scalar operations
   * Optimized implementation without data-dependent branches of arithmetic modulo the curve's order.
@@ -45,9 +51,11 @@ Implementation details
   * Optionally (off by default) use secp256k1's efficiently-computable endomorphism to split the P multiplicand into 2 half-sized ones.
 * Point multiplication for signing
   * Use a precomputed table of multiples of powers of 16 multiplied with the generator, so general multiplication becomes a series of additions.
-  * Access the table with branch-free conditional moves so memory access is uniform.
-  * No data-dependent branches
-  * The precomputed tables add and eventually subtract points for which no known scalar (private key) is known, preventing even an attacker with control over the private key used to control the data internally.
+  * Intended to be completely free of timing sidechannels for secret-key operations (on reasonable hardware/toolchains)
+    * Access the table with branch-free conditional moves so memory access is uniform.
+    * No data-dependent branches
+  * Optional runtime blinding which attempts to frustrate differential power analysis.
+  * The precomputed tables add and eventually subtract points for which no known scalar (secret key) is known, preventing even an attacker with control over the secret key used to control the data internally.
 
 Build steps
 -----------
@@ -57,5 +65,40 @@ libsecp256k1 is built using autotools:
     $ ./autogen.sh
     $ ./configure
     $ make
-    $ ./tests
+    $ make check
     $ sudo make install  # optional
+
+Exhaustive tests
+-----------
+
+    $ ./exhaustive_tests
+
+With valgrind, you might need to increase the max stack size:
+
+    $ valgrind --max-stackframe=2500000 ./exhaustive_tests
+
+Test coverage
+-----------
+
+This library aims to have full coverage of the reachable lines and branches.
+
+To create a test coverage report, configure with `--enable-coverage` (use of GCC is necessary):
+
+    $ ./configure --enable-coverage
+
+Run the tests:
+
+    $ make check
+
+To create a report, `gcovr` is recommended, as it includes branch coverage reporting:
+
+    $ gcovr --exclude 'src/bench*' --print-summary
+
+To create a HTML report with coloured and annotated source code:
+
+    $ gcovr --exclude 'src/bench*' --html --html-details -o coverage.html
+
+Reporting a vulnerability
+------------
+
+See [SECURITY.md](SECURITY.md)
diff --git a/crypto/secp256k1/libsecp256k1/SECURITY.md b/crypto/secp256k1/libsecp256k1/SECURITY.md
new file mode 100644
index 000000000..0e4d58803
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/SECURITY.md
@@ -0,0 +1,15 @@
+# Security Policy
+
+## Reporting a Vulnerability
+
+To report security issues send an email to secp256k1-security@bitcoincore.org (not for support).
+
+The following keys may be used to communicate sensitive information to developers:
+
+| Name | Fingerprint |
+|------|-------------|
+| Pieter Wuille | 133E AC17 9436 F14A 5CF1  B794 860F EB80 4E66 9320 |
+| Andrew Poelstra | 699A 63EF C17A D3A9 A34C  FFC0 7AD0 A91C 40BD 0091 |
+| Tim Ruffing | 09E0 3F87 1092 E40E 106E  902B 33BC 86AB 80FF 5516 |
+
+You can import a key by running the following command with that individual???s fingerprint: `gpg --recv-keys "<fingerprint>"` Ensure that you put quotes around fingerprints containing spaces.
diff --git a/crypto/secp256k1/libsecp256k1/build-aux/m4/ax_jni_include_dir.m4 b/crypto/secp256k1/libsecp256k1/build-aux/m4/ax_jni_include_dir.m4
deleted file mode 100644
index 1fc362761..000000000
--- a/crypto/secp256k1/libsecp256k1/build-aux/m4/ax_jni_include_dir.m4
+++ /dev/null
@@ -1,140 +0,0 @@
-# ===========================================================================
-#    http://www.gnu.org/software/autoconf-archive/ax_jni_include_dir.html
-# ===========================================================================
-#
-# SYNOPSIS
-#
-#   AX_JNI_INCLUDE_DIR
-#
-# DESCRIPTION
-#
-#   AX_JNI_INCLUDE_DIR finds include directories needed for compiling
-#   programs using the JNI interface.
-#
-#   JNI include directories are usually in the Java distribution. This is
-#   deduced from the value of $JAVA_HOME, $JAVAC, or the path to "javac", in
-#   that order. When this macro completes, a list of directories is left in
-#   the variable JNI_INCLUDE_DIRS.
-#
-#   Example usage follows:
-#
-#     AX_JNI_INCLUDE_DIR
-#
-#     for JNI_INCLUDE_DIR in $JNI_INCLUDE_DIRS
-#     do
-#             CPPFLAGS="$CPPFLAGS -I$JNI_INCLUDE_DIR"
-#     done
-#
-#   If you want to force a specific compiler:
-#
-#   - at the configure.in level, set JAVAC=yourcompiler before calling
-#   AX_JNI_INCLUDE_DIR
-#
-#   - at the configure level, setenv JAVAC
-#
-#   Note: This macro can work with the autoconf M4 macros for Java programs.
-#   This particular macro is not part of the original set of macros.
-#
-# LICENSE
-#
-#   Copyright (c) 2008 Don Anderson <dda@sleepycat.com>
-#
-#   Copying and distribution of this file, with or without modification, are
-#   permitted in any medium without royalty provided the copyright notice
-#   and this notice are preserved. This file is offered as-is, without any
-#   warranty.
-
-#serial 10
-
-AU_ALIAS([AC_JNI_INCLUDE_DIR], [AX_JNI_INCLUDE_DIR])
-AC_DEFUN([AX_JNI_INCLUDE_DIR],[
-
-JNI_INCLUDE_DIRS=""
-
-if test "x$JAVA_HOME" != x; then
-	_JTOPDIR="$JAVA_HOME"
-else
-	if test "x$JAVAC" = x; then
-		JAVAC=javac
-	fi
-	AC_PATH_PROG([_ACJNI_JAVAC], [$JAVAC], [no])
-	if test "x$_ACJNI_JAVAC" = xno; then
-		AC_MSG_WARN([cannot find JDK; try setting \$JAVAC or \$JAVA_HOME])
-	fi
-	_ACJNI_FOLLOW_SYMLINKS("$_ACJNI_JAVAC")
-	_JTOPDIR=`echo "$_ACJNI_FOLLOWED" | sed -e 's://*:/:g' -e 's:/[[^/]]*$::'`
-fi
-
-case "$host_os" in
-        darwin*)        _JTOPDIR=`echo "$_JTOPDIR" | sed -e 's:/[[^/]]*$::'`
-                        _JINC="$_JTOPDIR/Headers";;
-        *)              _JINC="$_JTOPDIR/include";;
-esac
-_AS_ECHO_LOG([_JTOPDIR=$_JTOPDIR])
-_AS_ECHO_LOG([_JINC=$_JINC])
-
-# On Mac OS X 10.6.4, jni.h is a symlink:
-# /System/Library/Frameworks/JavaVM.framework/Versions/Current/Headers/jni.h
-# -> ../../CurrentJDK/Headers/jni.h.
-
-AC_CACHE_CHECK(jni headers, ac_cv_jni_header_path,
-[
-if test -f "$_JINC/jni.h"; then
-  ac_cv_jni_header_path="$_JINC"
-  JNI_INCLUDE_DIRS="$JNI_INCLUDE_DIRS $ac_cv_jni_header_path"
-else
-  _JTOPDIR=`echo "$_JTOPDIR" | sed -e 's:/[[^/]]*$::'`
-  if test -f "$_JTOPDIR/include/jni.h"; then
-    ac_cv_jni_header_path="$_JTOPDIR/include"
-    JNI_INCLUDE_DIRS="$JNI_INCLUDE_DIRS $ac_cv_jni_header_path"
-  else
-    ac_cv_jni_header_path=none
-  fi
-fi
-])
-
-
-
-# get the likely subdirectories for system specific java includes
-case "$host_os" in
-bsdi*)          _JNI_INC_SUBDIRS="bsdos";;
-darwin*)        _JNI_INC_SUBDIRS="darwin";;
-freebsd*)       _JNI_INC_SUBDIRS="freebsd";;
-linux*)         _JNI_INC_SUBDIRS="linux genunix";;
-osf*)           _JNI_INC_SUBDIRS="alpha";;
-solaris*)       _JNI_INC_SUBDIRS="solaris";;
-mingw*)		_JNI_INC_SUBDIRS="win32";;
-cygwin*)	_JNI_INC_SUBDIRS="win32";;
-*)              _JNI_INC_SUBDIRS="genunix";;
-esac
-
-if test "x$ac_cv_jni_header_path" != "xnone"; then
-  # add any subdirectories that are present
-  for JINCSUBDIR in $_JNI_INC_SUBDIRS
-  do
-      if test -d "$_JTOPDIR/include/$JINCSUBDIR"; then
-           JNI_INCLUDE_DIRS="$JNI_INCLUDE_DIRS $_JTOPDIR/include/$JINCSUBDIR"
-      fi
-  done
-fi
-])
-
-# _ACJNI_FOLLOW_SYMLINKS <path>
-# Follows symbolic links on <path>,
-# finally setting variable _ACJNI_FOLLOWED
-# ----------------------------------------
-AC_DEFUN([_ACJNI_FOLLOW_SYMLINKS],[
-# find the include directory relative to the javac executable
-_cur="$1"
-while ls -ld "$_cur" 2>/dev/null | grep " -> " >/dev/null; do
-        AC_MSG_CHECKING([symlink for $_cur])
-        _slink=`ls -ld "$_cur" | sed 's/.* -> //'`
-        case "$_slink" in
-        /*) _cur="$_slink";;
-        # 'X' avoids triggering unwanted echo options.
-        *) _cur=`echo "X$_cur" | sed -e 's/^X//' -e 's:[[^/]]*$::'`"$_slink";;
-        esac
-        AC_MSG_RESULT([$_cur])
-done
-_ACJNI_FOLLOWED="$_cur"
-])# _ACJNI
diff --git a/crypto/secp256k1/libsecp256k1/build-aux/m4/bitcoin_secp.m4 b/crypto/secp256k1/libsecp256k1/build-aux/m4/bitcoin_secp.m4
index b74acb8c1..1b2b71e6a 100644
--- a/crypto/secp256k1/libsecp256k1/build-aux/m4/bitcoin_secp.m4
+++ b/crypto/secp256k1/libsecp256k1/build-aux/m4/bitcoin_secp.m4
@@ -38,6 +38,8 @@ AC_DEFUN([SECP_OPENSSL_CHECK],[
   fi
 if test x"$has_libcrypto" = x"yes" && test x"$has_openssl_ec" = x; then
   AC_MSG_CHECKING(for EC functions in libcrypto)
+  CPPFLAGS_TEMP="$CPPFLAGS"
+  CPPFLAGS="$CRYPTO_CPPFLAGS $CPPFLAGS"
   AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
     #include <openssl/ec.h>
     #include <openssl/ecdsa.h>
@@ -48,10 +50,10 @@ if test x"$has_libcrypto" = x"yes" && test x"$has_openssl_ec" = x; then
     EC_KEY_free(eckey);
     ECDSA_SIG *sig_openssl;
     sig_openssl = ECDSA_SIG_new();
-    (void)sig_openssl->r;
     ECDSA_SIG_free(sig_openssl);
   ]])],[has_openssl_ec=yes],[has_openssl_ec=no])
   AC_MSG_RESULT([$has_openssl_ec])
+  CPPFLAGS="$CPPFLAGS_TEMP"
 fi
 ])
 
diff --git a/crypto/secp256k1/libsecp256k1/configure.ac b/crypto/secp256k1/libsecp256k1/configure.ac
index e5fcbcb4e..6021b760b 100644
--- a/crypto/secp256k1/libsecp256k1/configure.ac
+++ b/crypto/secp256k1/libsecp256k1/configure.ac
@@ -7,6 +7,11 @@ AH_TOP([#ifndef LIBSECP256K1_CONFIG_H])
 AH_TOP([#define LIBSECP256K1_CONFIG_H])
 AH_BOTTOM([#endif /*LIBSECP256K1_CONFIG_H*/])
 AM_INIT_AUTOMAKE([foreign subdir-objects])
+
+# Set -g if CFLAGS are not already set, which matches the default autoconf
+# behavior (see PROG_CC in the Autoconf manual) with the exception that we don't
+# set -O2 here because we set it in any case (see further down).
+: ${CFLAGS="-g"}
 LT_INIT
 
 dnl make the compilation flags quiet unless V=1 is used
@@ -19,10 +24,6 @@ AC_PATH_TOOL(RANLIB, ranlib)
 AC_PATH_TOOL(STRIP, strip)
 AX_PROG_CC_FOR_BUILD
 
-if test "x$CFLAGS" = "x"; then
-  CFLAGS="-g"
-fi
-
 AM_PROG_CC_C_O
 
 AC_PROG_CC_C89
@@ -45,6 +46,7 @@ case $host_os in
          if test x$openssl_prefix != x; then
            PKG_CONFIG_PATH="$openssl_prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
            export PKG_CONFIG_PATH
+           CRYPTO_CPPFLAGS="-I$openssl_prefix/include"
          fi
          if test x$gmp_prefix != x; then
            GMP_CPPFLAGS="-I$gmp_prefix/include"
@@ -63,11 +65,11 @@ case $host_os in
    ;;
 esac
 
-CFLAGS="$CFLAGS -W"
+CFLAGS="-W $CFLAGS"
 
 warn_CFLAGS="-std=c89 -pedantic -Wall -Wextra -Wcast-align -Wnested-externs -Wshadow -Wstrict-prototypes -Wno-unused-function -Wno-long-long -Wno-overlength-strings"
 saved_CFLAGS="$CFLAGS"
-CFLAGS="$CFLAGS $warn_CFLAGS"
+CFLAGS="$warn_CFLAGS $CFLAGS"
 AC_MSG_CHECKING([if ${CC} supports ${warn_CFLAGS}])
 AC_COMPILE_IFELSE([AC_LANG_SOURCE([[char foo;]])],
     [ AC_MSG_RESULT([yes]) ],
@@ -76,7 +78,7 @@ AC_COMPILE_IFELSE([AC_LANG_SOURCE([[char foo;]])],
     ])
 
 saved_CFLAGS="$CFLAGS"
-CFLAGS="$CFLAGS -fvisibility=hidden"
+CFLAGS="-fvisibility=hidden $CFLAGS"
 AC_MSG_CHECKING([if ${CC} supports -fvisibility=hidden])
 AC_COMPILE_IFELSE([AC_LANG_SOURCE([[char foo;]])],
     [ AC_MSG_RESULT([yes]) ],
@@ -85,42 +87,42 @@ AC_COMPILE_IFELSE([AC_LANG_SOURCE([[char foo;]])],
     ])
 
 AC_ARG_ENABLE(benchmark,
-    AS_HELP_STRING([--enable-benchmark],[compile benchmark (default is no)]),
+    AS_HELP_STRING([--enable-benchmark],[compile benchmark [default=yes]]),
     [use_benchmark=$enableval],
-    [use_benchmark=no])
+    [use_benchmark=yes])
 
 AC_ARG_ENABLE(coverage,
-    AS_HELP_STRING([--enable-coverage],[enable compiler flags to support kcov coverage analysis]),
+    AS_HELP_STRING([--enable-coverage],[enable compiler flags to support kcov coverage analysis [default=no]]),
     [enable_coverage=$enableval],
     [enable_coverage=no])
 
 AC_ARG_ENABLE(tests,
-    AS_HELP_STRING([--enable-tests],[compile tests (default is yes)]),
+    AS_HELP_STRING([--enable-tests],[compile tests [default=yes]]),
     [use_tests=$enableval],
     [use_tests=yes])
 
 AC_ARG_ENABLE(openssl_tests,
-    AS_HELP_STRING([--enable-openssl-tests],[enable OpenSSL tests, if OpenSSL is available (default is auto)]),
+    AS_HELP_STRING([--enable-openssl-tests],[enable OpenSSL tests [default=auto]]),
     [enable_openssl_tests=$enableval],
     [enable_openssl_tests=auto])
 
 AC_ARG_ENABLE(experimental,
-    AS_HELP_STRING([--enable-experimental],[allow experimental configure options (default is no)]),
+    AS_HELP_STRING([--enable-experimental],[allow experimental configure options [default=no]]),
     [use_experimental=$enableval],
     [use_experimental=no])
 
 AC_ARG_ENABLE(exhaustive_tests,
-    AS_HELP_STRING([--enable-exhaustive-tests],[compile exhaustive tests (default is yes)]),
+    AS_HELP_STRING([--enable-exhaustive-tests],[compile exhaustive tests [default=yes]]),
     [use_exhaustive_tests=$enableval],
     [use_exhaustive_tests=yes])
 
 AC_ARG_ENABLE(endomorphism,
-    AS_HELP_STRING([--enable-endomorphism],[enable endomorphism (default is no)]),
+    AS_HELP_STRING([--enable-endomorphism],[enable endomorphism [default=no]]),
     [use_endomorphism=$enableval],
     [use_endomorphism=no])
 
 AC_ARG_ENABLE(ecmult_static_precomputation,
-    AS_HELP_STRING([--enable-ecmult-static-precomputation],[enable precomputed ecmult table for signing (default is yes)]),
+    AS_HELP_STRING([--enable-ecmult-static-precomputation],[enable precomputed ecmult table for signing [default=auto]]),
     [use_ecmult_static_precomputation=$enableval],
     [use_ecmult_static_precomputation=auto])
 
@@ -130,65 +132,106 @@ AC_ARG_ENABLE(module_ecdh,
     [enable_module_ecdh=no])
 
 AC_ARG_ENABLE(module_recovery,
-    AS_HELP_STRING([--enable-module-recovery],[enable ECDSA pubkey recovery module (default is no)]),
+    AS_HELP_STRING([--enable-module-recovery],[enable ECDSA pubkey recovery module [default=no]]),
     [enable_module_recovery=$enableval],
     [enable_module_recovery=no])
 
-AC_ARG_ENABLE(jni,
-    AS_HELP_STRING([--enable-jni],[enable libsecp256k1_jni (default is auto)]),
-    [use_jni=$enableval],
-    [use_jni=auto])
+AC_ARG_ENABLE(external_default_callbacks,
+    AS_HELP_STRING([--enable-external-default-callbacks],[enable external default callback functions [default=no]]),
+    [use_external_default_callbacks=$enableval],
+    [use_external_default_callbacks=no])
 
 AC_ARG_WITH([field], [AS_HELP_STRING([--with-field=64bit|32bit|auto],
-[Specify Field Implementation. Default is auto])],[req_field=$withval], [req_field=auto])
+[finite field implementation to use [default=auto]])],[req_field=$withval], [req_field=auto])
 
 AC_ARG_WITH([bignum], [AS_HELP_STRING([--with-bignum=gmp|no|auto],
-[Specify Bignum Implementation. Default is auto])],[req_bignum=$withval], [req_bignum=auto])
+[bignum implementation to use [default=auto]])],[req_bignum=$withval], [req_bignum=auto])
 
 AC_ARG_WITH([scalar], [AS_HELP_STRING([--with-scalar=64bit|32bit|auto],
-[Specify scalar implementation. Default is auto])],[req_scalar=$withval], [req_scalar=auto])
-
-AC_ARG_WITH([asm], [AS_HELP_STRING([--with-asm=x86_64|arm|no|auto]
-[Specify assembly optimizations to use. Default is auto (experimental: arm)])],[req_asm=$withval], [req_asm=auto])
+[scalar implementation to use [default=auto]])],[req_scalar=$withval], [req_scalar=auto])
+
+AC_ARG_WITH([asm], [AS_HELP_STRING([--with-asm=x86_64|arm|no|auto],
+[assembly optimizations to use??(experimental: arm) [default=auto]])],[req_asm=$withval], [req_asm=auto])
+
+AC_ARG_WITH([ecmult-window], [AS_HELP_STRING([--with-ecmult-window=SIZE|auto],
+[window size for ecmult precomputation for verification, specified as integer in range [2..24].]
+[Larger values result in possibly better performance at the cost of an exponentially larger precomputed table.]
+[The table will store 2^(SIZE-2) * 64 bytes of data but can be larger in memory due to platform-specific padding and alignment.]
+[If the endomorphism optimization is enabled, two tables of this size are used instead of only one.]
+["auto" is a reasonable setting for desktop machines (currently 15). [default=auto]]
+)],
+[req_ecmult_window=$withval], [req_ecmult_window=auto])
+
+AC_ARG_WITH([ecmult-gen-precision], [AS_HELP_STRING([--with-ecmult-gen-precision=2|4|8|auto],
+[Precision bits to tune the precomputed table size for signing.]
+[The size of the table is 32kB for 2 bits, 64kB for 4 bits, 512kB for 8 bits of precision.]
+[A larger table size usually results in possible faster signing.]
+["auto" is a reasonable setting for desktop machines (currently 4). [default=auto]]
+)],
+[req_ecmult_gen_precision=$withval], [req_ecmult_gen_precision=auto])
 
 AC_CHECK_TYPES([__int128])
 
-AC_MSG_CHECKING([for __builtin_expect])
-AC_COMPILE_IFELSE([AC_LANG_SOURCE([[void myfunc() {__builtin_expect(0,0);}]])],
-    [ AC_MSG_RESULT([yes]);AC_DEFINE(HAVE_BUILTIN_EXPECT,1,[Define this symbol if __builtin_expect is available]) ],
-    [ AC_MSG_RESULT([no])
-    ])
+AC_CHECK_HEADER([valgrind/memcheck.h], [enable_valgrind=yes], [enable_valgrind=no], [])
+AM_CONDITIONAL([VALGRIND_ENABLED],[test "$enable_valgrind" = "yes"])
 
 if test x"$enable_coverage" = x"yes"; then
     AC_DEFINE(COVERAGE, 1, [Define this symbol to compile out all VERIFY code])
-    CFLAGS="$CFLAGS -O0 --coverage"
-    LDFLAGS="--coverage"
+    CFLAGS="-O0 --coverage $CFLAGS"
+    LDFLAGS="--coverage $LDFLAGS"
 else
-    CFLAGS="$CFLAGS -O3"
+    CFLAGS="-O2 $CFLAGS"
 fi
 
 if test x"$use_ecmult_static_precomputation" != x"no"; then
+  # Temporarily switch to an environment for the native compiler
   save_cross_compiling=$cross_compiling
   cross_compiling=no
-  TEMP_CC="$CC"
+  SAVE_CC="$CC"
   CC="$CC_FOR_BUILD"
-  AC_MSG_CHECKING([native compiler: ${CC_FOR_BUILD}])
+  SAVE_CFLAGS="$CFLAGS"
+  CFLAGS="$CFLAGS_FOR_BUILD"
+  SAVE_CPPFLAGS="$CPPFLAGS"
+  CPPFLAGS="$CPPFLAGS_FOR_BUILD"
+  SAVE_LDFLAGS="$LDFLAGS"
+  LDFLAGS="$LDFLAGS_FOR_BUILD"
+
+  warn_CFLAGS_FOR_BUILD="-Wall -Wextra -Wno-unused-function"
+  saved_CFLAGS="$CFLAGS"
+  CFLAGS="$warn_CFLAGS_FOR_BUILD $CFLAGS"
+  AC_MSG_CHECKING([if native ${CC_FOR_BUILD} supports ${warn_CFLAGS_FOR_BUILD}])
+  AC_COMPILE_IFELSE([AC_LANG_SOURCE([[char foo;]])],
+      [ AC_MSG_RESULT([yes]) ],
+      [ AC_MSG_RESULT([no])
+        CFLAGS="$saved_CFLAGS"
+      ])
+
+  AC_MSG_CHECKING([for working native compiler: ${CC_FOR_BUILD}])
   AC_RUN_IFELSE(
-    [AC_LANG_PROGRAM([], [return 0])],
+    [AC_LANG_PROGRAM([], [])],
     [working_native_cc=yes],
-    [working_native_cc=no],[dnl])
-  CC="$TEMP_CC"
+    [working_native_cc=no],[:])
+
+  CFLAGS_FOR_BUILD="$CFLAGS"
+
+  # Restore the environment
   cross_compiling=$save_cross_compiling
+  CC="$SAVE_CC"
+  CFLAGS="$SAVE_CFLAGS"
+  CPPFLAGS="$SAVE_CPPFLAGS"
+  LDFLAGS="$SAVE_LDFLAGS"
 
   if test x"$working_native_cc" = x"no"; then
+    AC_MSG_RESULT([no])
     set_precomp=no
+    m4_define([please_set_for_build], [Please set CC_FOR_BUILD, CFLAGS_FOR_BUILD, CPPFLAGS_FOR_BUILD, and/or LDFLAGS_FOR_BUILD.])
     if test x"$use_ecmult_static_precomputation" = x"yes";  then
-      AC_MSG_ERROR([${CC_FOR_BUILD} does not produce working binaries. Please set CC_FOR_BUILD])
+      AC_MSG_ERROR([native compiler ${CC_FOR_BUILD} does not produce working binaries. please_set_for_build])
     else
-      AC_MSG_RESULT([${CC_FOR_BUILD} does not produce working binaries. Please set CC_FOR_BUILD])
+      AC_MSG_WARN([Disabling statically generated ecmult table because the native compiler ${CC_FOR_BUILD} does not produce working binaries. please_set_for_build])
     fi
   else
-    AC_MSG_RESULT([ok])
+    AC_MSG_RESULT([yes])
     set_precomp=yes
   fi
 else
@@ -366,12 +409,50 @@ case $set_scalar in
   ;;
 esac
 
+#set ecmult window size
+if test x"$req_ecmult_window" = x"auto"; then
+  set_ecmult_window=15
+else
+  set_ecmult_window=$req_ecmult_window
+fi
+
+error_window_size=['window size for ecmult precomputation not an integer in range [2..24] or "auto"']
+case $set_ecmult_window in
+''|*[[!0-9]]*)
+  # no valid integer
+  AC_MSG_ERROR($error_window_size)
+  ;;
+*)
+  if test "$set_ecmult_window" -lt 2 -o "$set_ecmult_window" -gt 24 ; then
+    # not in range
+    AC_MSG_ERROR($error_window_size)
+  fi
+  AC_DEFINE_UNQUOTED(ECMULT_WINDOW_SIZE, $set_ecmult_window, [Set window size for ecmult precomputation])
+  ;;
+esac
+
+#set ecmult gen precision
+if test x"$req_ecmult_gen_precision" = x"auto"; then
+  set_ecmult_gen_precision=4
+else
+  set_ecmult_gen_precision=$req_ecmult_gen_precision
+fi
+
+case $set_ecmult_gen_precision in
+2|4|8)
+  AC_DEFINE_UNQUOTED(ECMULT_GEN_PREC_BITS, $set_ecmult_gen_precision, [Set ecmult gen precision bits])
+  ;;
+*)
+  AC_MSG_ERROR(['ecmult gen precision not 2, 4, 8 or "auto"'])
+  ;;
+esac
+
 if test x"$use_tests" = x"yes"; then
   SECP_OPENSSL_CHECK
   if test x"$has_openssl_ec" = x"yes"; then
     if test x"$enable_openssl_tests" != x"no"; then
       AC_DEFINE(ENABLE_OPENSSL_TESTS, 1, [Define this symbol if OpenSSL EC functions are available])
-      SECP_TEST_INCLUDES="$SSL_CFLAGS $CRYPTO_CFLAGS"
+      SECP_TEST_INCLUDES="$SSL_CFLAGS $CRYPTO_CFLAGS $CRYPTO_CPPFLAGS"
       SECP_TEST_LIBS="$CRYPTO_LIBS"
 
       case $host in
@@ -391,29 +472,6 @@ else
   fi
 fi
 
-if test x"$use_jni" != x"no"; then
-  AX_JNI_INCLUDE_DIR
-  have_jni_dependencies=yes
-  if test x"$enable_module_ecdh" = x"no"; then
-    have_jni_dependencies=no
-  fi
-  if test "x$JNI_INCLUDE_DIRS" = "x"; then
-    have_jni_dependencies=no
-  fi
-  if test "x$have_jni_dependencies" = "xno"; then
-    if test x"$use_jni" = x"yes"; then
-      AC_MSG_ERROR([jni support explicitly requested but headers/dependencies were not found. Enable ECDH and try again.])
-    fi
-    AC_MSG_WARN([jni headers/dependencies not found. jni support disabled])
-    use_jni=no
-  else
-    use_jni=yes
-    for JNI_INCLUDE_DIR in $JNI_INCLUDE_DIRS; do
-      JNI_INCLUDES="$JNI_INCLUDES -I$JNI_INCLUDE_DIR"
-    done
-  fi
-fi
-
 if test x"$set_bignum" = x"gmp"; then
   SECP_LIBS="$SECP_LIBS $GMP_LIBS"
   SECP_INCLUDES="$SECP_INCLUDES $GMP_CPPFLAGS"
@@ -441,16 +499,9 @@ if test x"$use_external_asm" = x"yes"; then
   AC_DEFINE(USE_EXTERNAL_ASM, 1, [Define this symbol if an external (non-inline) assembly implementation is used])
 fi
 
-AC_MSG_NOTICE([Using static precomputation: $set_precomp])
-AC_MSG_NOTICE([Using assembly optimizations: $set_asm])
-AC_MSG_NOTICE([Using field implementation: $set_field])
-AC_MSG_NOTICE([Using bignum implementation: $set_bignum])
-AC_MSG_NOTICE([Using scalar implementation: $set_scalar])
-AC_MSG_NOTICE([Using endomorphism optimizations: $use_endomorphism])
-AC_MSG_NOTICE([Building for coverage analysis: $enable_coverage])
-AC_MSG_NOTICE([Building ECDH module: $enable_module_ecdh])
-AC_MSG_NOTICE([Building ECDSA pubkey recovery module: $enable_module_recovery])
-AC_MSG_NOTICE([Using jni: $use_jni])
+if test x"$use_external_default_callbacks" = x"yes"; then
+  AC_DEFINE(USE_EXTERNAL_DEFAULT_CALLBACKS, 1, [Define this symbol if an external implementation of the default callbacks is used])
+fi
 
 if test x"$enable_experimental" = x"yes"; then
   AC_MSG_NOTICE([******])
@@ -469,7 +520,6 @@ fi
 
 AC_CONFIG_HEADERS([src/libsecp256k1-config.h])
 AC_CONFIG_FILES([Makefile libsecp256k1.pc])
-AC_SUBST(JNI_INCLUDES)
 AC_SUBST(SECP_INCLUDES)
 AC_SUBST(SECP_LIBS)
 AC_SUBST(SECP_TEST_LIBS)
@@ -481,7 +531,6 @@ AM_CONDITIONAL([USE_BENCHMARK], [test x"$use_benchmark" = x"yes"])
 AM_CONDITIONAL([USE_ECMULT_STATIC_PRECOMPUTATION], [test x"$set_precomp" = x"yes"])
 AM_CONDITIONAL([ENABLE_MODULE_ECDH], [test x"$enable_module_ecdh" = x"yes"])
 AM_CONDITIONAL([ENABLE_MODULE_RECOVERY], [test x"$enable_module_recovery" = x"yes"])
-AM_CONDITIONAL([USE_JNI], [test x"$use_jni" == x"yes"])
 AM_CONDITIONAL([USE_EXTERNAL_ASM], [test x"$use_external_asm" = x"yes"])
 AM_CONDITIONAL([USE_ASM_ARM], [test x"$set_asm" = x"arm"])
 
@@ -491,3 +540,27 @@ unset PKG_CONFIG_PATH
 PKG_CONFIG_PATH="$PKGCONFIG_PATH_TEMP"
 
 AC_OUTPUT
+
+echo
+echo "Build Options:"
+echo "  with endomorphism       = $use_endomorphism"
+echo "  with ecmult precomp     = $set_precomp"
+echo "  with external callbacks = $use_external_default_callbacks"
+echo "  with benchmarks         = $use_benchmark"
+echo "  with coverage           = $enable_coverage"
+echo "  module ecdh             = $enable_module_ecdh"
+echo "  module recovery         = $enable_module_recovery"
+echo
+echo "  asm                     = $set_asm"
+echo "  bignum                  = $set_bignum"
+echo "  field                   = $set_field"
+echo "  scalar                  = $set_scalar"
+echo "  ecmult window size      = $set_ecmult_window"
+echo "  ecmult gen prec. bits   = $set_ecmult_gen_precision"
+echo
+echo "  valgrind                = $enable_valgrind"
+echo "  CC                      = $CC"
+echo "  CFLAGS                  = $CFLAGS"
+echo "  CPPFLAGS                = $CPPFLAGS"
+echo "  LDFLAGS                 = $LDFLAGS"
+echo
diff --git a/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.c b/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.c
index 5b141a994..e177a0562 100644
--- a/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.c
+++ b/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.c
@@ -32,7 +32,7 @@ int ecdsa_signature_parse_der_lax(const secp256k1_context* ctx, secp256k1_ecdsa_
     lenbyte = input[pos++];
     if (lenbyte & 0x80) {
         lenbyte -= 0x80;
-        if (pos + lenbyte > inputlen) {
+        if (lenbyte > inputlen - pos) {
             return 0;
         }
         pos += lenbyte;
@@ -51,7 +51,7 @@ int ecdsa_signature_parse_der_lax(const secp256k1_context* ctx, secp256k1_ecdsa_
     lenbyte = input[pos++];
     if (lenbyte & 0x80) {
         lenbyte -= 0x80;
-        if (pos + lenbyte > inputlen) {
+        if (lenbyte > inputlen - pos) {
             return 0;
         }
         while (lenbyte > 0 && input[pos] == 0) {
@@ -89,7 +89,7 @@ int ecdsa_signature_parse_der_lax(const secp256k1_context* ctx, secp256k1_ecdsa_
     lenbyte = input[pos++];
     if (lenbyte & 0x80) {
         lenbyte -= 0x80;
-        if (pos + lenbyte > inputlen) {
+        if (lenbyte > inputlen - pos) {
             return 0;
         }
         while (lenbyte > 0 && input[pos] == 0) {
diff --git a/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.h b/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.h
index 6d27871a7..7eaf63bf6 100644
--- a/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.h
+++ b/crypto/secp256k1/libsecp256k1/contrib/lax_der_parsing.h
@@ -48,14 +48,14 @@
  *   8.3.1.
  */
 
-#ifndef _SECP256K1_CONTRIB_LAX_DER_PARSING_H_
-#define _SECP256K1_CONTRIB_LAX_DER_PARSING_H_
+#ifndef SECP256K1_CONTRIB_LAX_DER_PARSING_H
+#define SECP256K1_CONTRIB_LAX_DER_PARSING_H
 
 #include <secp256k1.h>
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 extern "C" {
-# endif
+#endif
 
 /** Parse a signature in "lax DER" format
  *
@@ -88,4 +88,4 @@ int ecdsa_signature_parse_der_lax(
 }
 #endif
 
-#endif
+#endif /* SECP256K1_CONTRIB_LAX_DER_PARSING_H */
diff --git a/crypto/secp256k1/libsecp256k1/contrib/lax_der_privatekey_parsing.h b/crypto/secp256k1/libsecp256k1/contrib/lax_der_privatekey_parsing.h
index 2fd088f8a..fece261fb 100644
--- a/crypto/secp256k1/libsecp256k1/contrib/lax_der_privatekey_parsing.h
+++ b/crypto/secp256k1/libsecp256k1/contrib/lax_der_privatekey_parsing.h
@@ -25,14 +25,14 @@
  * library are sufficient.
  */
 
-#ifndef _SECP256K1_CONTRIB_BER_PRIVATEKEY_H_
-#define _SECP256K1_CONTRIB_BER_PRIVATEKEY_H_
+#ifndef SECP256K1_CONTRIB_BER_PRIVATEKEY_H
+#define SECP256K1_CONTRIB_BER_PRIVATEKEY_H
 
 #include <secp256k1.h>
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 extern "C" {
-# endif
+#endif
 
 /** Export a private key in DER format.
  *
@@ -87,4 +87,4 @@ SECP256K1_WARN_UNUSED_RESULT int ec_privkey_import_der(
 }
 #endif
 
-#endif
+#endif /* SECP256K1_CONTRIB_BER_PRIVATEKEY_H */
diff --git a/crypto/secp256k1/libsecp256k1/contrib/travis.sh b/crypto/secp256k1/libsecp256k1/contrib/travis.sh
new file mode 100755
index 000000000..3909d16a2
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/contrib/travis.sh
@@ -0,0 +1,65 @@
+#!/bin/sh
+
+set -e
+set -x
+
+if [ -n "$HOST" ]
+then
+    export USE_HOST="--host=$HOST"
+fi
+if [ "$HOST" = "i686-linux-gnu" ]
+then
+    export CC="$CC -m32"
+fi
+if [ "$TRAVIS_OS_NAME" = "osx" ] && [ "$TRAVIS_COMPILER" = "gcc" ]
+then
+    export CC="gcc-9"
+fi
+
+./configure \
+    --enable-experimental="$EXPERIMENTAL" --enable-endomorphism="$ENDOMORPHISM" \
+    --with-field="$FIELD" --with-bignum="$BIGNUM" --with-asm="$ASM" --with-scalar="$SCALAR" \
+    --enable-ecmult-static-precomputation="$STATICPRECOMPUTATION" --with-ecmult-gen-precision="$ECMULTGENPRECISION" \
+    --enable-module-ecdh="$ECDH" --enable-module-recovery="$RECOVERY" "$EXTRAFLAGS" "$USE_HOST"
+
+if [ -n "$BUILD" ]
+then
+    make -j2 "$BUILD"
+fi
+if [ -n "$VALGRIND" ]
+then
+    make -j2
+    # the `--error-exitcode` is required to make the test fail if valgrind found errors, otherwise it'll return 0 (http://valgrind.org/docs/manual/manual-core.html)
+    valgrind --error-exitcode=42 ./tests 16
+    valgrind --error-exitcode=42 ./exhaustive_tests
+fi
+if [ -n "$BENCH" ]
+then
+    if [ -n "$VALGRIND" ]
+    then
+        # Using the local `libtool` because on macOS the system's libtool has nothing to do with GNU libtool
+        EXEC='./libtool --mode=execute valgrind --error-exitcode=42'
+    else
+        EXEC=
+    fi
+    # This limits the iterations in the benchmarks below to ITER(set in .travis.yml) iterations.
+    export SECP256K1_BENCH_ITERS="$ITERS"
+    {
+        $EXEC ./bench_ecmult
+        $EXEC ./bench_internal
+        $EXEC ./bench_sign
+        $EXEC ./bench_verify
+    } >> bench.log 2>&1
+    if [ "$RECOVERY" = "yes" ]
+    then
+        $EXEC ./bench_recover >> bench.log 2>&1
+    fi
+    if [ "$ECDH" = "yes" ]
+    then
+        $EXEC ./bench_ecdh >> bench.log 2>&1
+    fi
+fi
+if [ -n "$CTIMETEST" ]
+then
+    ./libtool --mode=execute valgrind --error-exitcode=42 ./valgrind_ctime_test > valgrind_ctime_test.log 2>&1
+fi
diff --git a/crypto/secp256k1/libsecp256k1/include/secp256k1.h b/crypto/secp256k1/libsecp256k1/include/secp256k1.h
index f268e309d..2ba2dca38 100644
--- a/crypto/secp256k1/libsecp256k1/include/secp256k1.h
+++ b/crypto/secp256k1/libsecp256k1/include/secp256k1.h
@@ -1,9 +1,9 @@
-#ifndef _SECP256K1_
-# define _SECP256K1_
+#ifndef SECP256K1_H
+#define SECP256K1_H
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 extern "C" {
-# endif
+#endif
 
 #include <stddef.h>
 
@@ -14,7 +14,7 @@ extern "C" {
  * 2. Array lengths always immediately the follow the argument whose length
  *    they describe, even if this violates rule 1.
  * 3. Within the OUT/OUTIN/IN groups, pointers to data that is typically generated
- *    later go first. This means: signatures, public nonces, private nonces,
+ *    later go first. This means: signatures, public nonces, secret nonces,
  *    messages, public keys, secret keys, tweaks.
  * 4. Arguments that are not data pointers go last, from more complex to less
  *    complex: function pointers, algorithm names, messages, void pointers,
@@ -33,15 +33,29 @@ extern "C" {
  *  verification).
  *
  *  A constructed context can safely be used from multiple threads
- *  simultaneously, but API call that take a non-const pointer to a context
+ *  simultaneously, but API calls that take a non-const pointer to a context
  *  need exclusive access to it. In particular this is the case for
- *  secp256k1_context_destroy and secp256k1_context_randomize.
+ *  secp256k1_context_destroy, secp256k1_context_preallocated_destroy,
+ *  and secp256k1_context_randomize.
  *
  *  Regarding randomization, either do it once at creation time (in which case
  *  you do not need any locking for the other calls), or use a read-write lock.
  */
 typedef struct secp256k1_context_struct secp256k1_context;
 
+/** Opaque data structure that holds rewriteable "scratch space"
+ *
+ *  The purpose of this structure is to replace dynamic memory allocations,
+ *  because we target architectures where this may not be available. It is
+ *  essentially a resizable (within specified parameters) block of bytes,
+ *  which is initially created either by memory allocation or TODO as a pointer
+ *  into some fixed rewritable space.
+ *
+ *  Unlike the context object, this cannot safely be shared between threads
+ *  without additional synchronization logic.
+ */
+typedef struct secp256k1_scratch_space_struct secp256k1_scratch_space;
+
 /** Opaque data structure that holds a parsed and valid public key.
  *
  *  The exact representation of data inside is implementation defined and not
@@ -61,7 +75,7 @@ typedef struct {
  *  however guaranteed to be 64 bytes in size, and can be safely copied/moved.
  *  If you need to convert to a format suitable for storage, transmission, or
  *  comparison, use the secp256k1_ecdsa_signature_serialize_* and
- *  secp256k1_ecdsa_signature_serialize_* functions.
+ *  secp256k1_ecdsa_signature_parse_* functions.
  */
 typedef struct {
     unsigned char data[64];
@@ -148,27 +162,54 @@ typedef int (*secp256k1_nonce_function)(
 /** The higher bits contain the actual data. Do not use directly. */
 #define SECP256K1_FLAGS_BIT_CONTEXT_VERIFY (1 << 8)
 #define SECP256K1_FLAGS_BIT_CONTEXT_SIGN (1 << 9)
+#define SECP256K1_FLAGS_BIT_CONTEXT_DECLASSIFY (1 << 10)
 #define SECP256K1_FLAGS_BIT_COMPRESSION (1 << 8)
 
-/** Flags to pass to secp256k1_context_create. */
+/** Flags to pass to secp256k1_context_create, secp256k1_context_preallocated_size, and
+ *  secp256k1_context_preallocated_create. */
 #define SECP256K1_CONTEXT_VERIFY (SECP256K1_FLAGS_TYPE_CONTEXT | SECP256K1_FLAGS_BIT_CONTEXT_VERIFY)
 #define SECP256K1_CONTEXT_SIGN (SECP256K1_FLAGS_TYPE_CONTEXT | SECP256K1_FLAGS_BIT_CONTEXT_SIGN)
+#define SECP256K1_CONTEXT_DECLASSIFY (SECP256K1_FLAGS_TYPE_CONTEXT | SECP256K1_FLAGS_BIT_CONTEXT_DECLASSIFY)
 #define SECP256K1_CONTEXT_NONE (SECP256K1_FLAGS_TYPE_CONTEXT)
 
-/** Flag to pass to secp256k1_ec_pubkey_serialize and secp256k1_ec_privkey_export. */
+/** Flag to pass to secp256k1_ec_pubkey_serialize. */
 #define SECP256K1_EC_COMPRESSED (SECP256K1_FLAGS_TYPE_COMPRESSION | SECP256K1_FLAGS_BIT_COMPRESSION)
 #define SECP256K1_EC_UNCOMPRESSED (SECP256K1_FLAGS_TYPE_COMPRESSION)
 
-/** Create a secp256k1 context object.
+/** Prefix byte used to tag various encoded curvepoints for specific purposes */
+#define SECP256K1_TAG_PUBKEY_EVEN 0x02
+#define SECP256K1_TAG_PUBKEY_ODD 0x03
+#define SECP256K1_TAG_PUBKEY_UNCOMPRESSED 0x04
+#define SECP256K1_TAG_PUBKEY_HYBRID_EVEN 0x06
+#define SECP256K1_TAG_PUBKEY_HYBRID_ODD 0x07
+
+/** A simple secp256k1 context object with no precomputed tables. These are useful for
+ *  type serialization/parsing functions which require a context object to maintain
+ *  API consistency, but currently do not require expensive precomputations or dynamic
+ *  allocations.
+ */
+SECP256K1_API extern const secp256k1_context *secp256k1_context_no_precomp;
+
+/** Create a secp256k1 context object (in dynamically allocated memory).
+ *
+ *  This function uses malloc to allocate memory. It is guaranteed that malloc is
+ *  called at most once for every call of this function. If you need to avoid dynamic
+ *  memory allocation entirely, see the functions in secp256k1_preallocated.h.
  *
  *  Returns: a newly created context object.
  *  In:      flags: which parts of the context to initialize.
+ *
+ *  See also secp256k1_context_randomize.
  */
 SECP256K1_API secp256k1_context* secp256k1_context_create(
     unsigned int flags
 ) SECP256K1_WARN_UNUSED_RESULT;
 
-/** Copies a secp256k1 context object.
+/** Copy a secp256k1 context object (into dynamically allocated memory).
+ *
+ *  This function uses malloc to allocate memory. It is guaranteed that malloc is
+ *  called at most once for every call of this function. If you need to avoid dynamic
+ *  memory allocation entirely, see the functions in secp256k1_preallocated.h.
  *
  *  Returns: a newly created context object.
  *  Args:    ctx: an existing context to copy (cannot be NULL)
@@ -177,10 +218,18 @@ SECP256K1_API secp256k1_context* secp256k1_context_clone(
     const secp256k1_context* ctx
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_WARN_UNUSED_RESULT;
 
-/** Destroy a secp256k1 context object.
+/** Destroy a secp256k1 context object (created in dynamically allocated memory).
  *
  *  The context pointer may not be used afterwards.
- *  Args:   ctx: an existing context to destroy (cannot be NULL)
+ *
+ *  The context to destroy must have been created using secp256k1_context_create
+ *  or secp256k1_context_clone. If the context has instead been created using
+ *  secp256k1_context_preallocated_create or secp256k1_context_preallocated_clone, the
+ *  behaviour is undefined. In that case, secp256k1_context_preallocated_destroy must
+ *  be used instead.
+ *
+ *  Args:   ctx: an existing context to destroy, constructed using
+ *               secp256k1_context_create or secp256k1_context_clone
  */
 SECP256K1_API void secp256k1_context_destroy(
     secp256k1_context* ctx
@@ -200,11 +249,28 @@ SECP256K1_API void secp256k1_context_destroy(
  *  to cause a crash, though its return value and output arguments are
  *  undefined.
  *
+ *  When this function has not been called (or called with fn==NULL), then the
+ *  default handler will be used.??The library provides a default handler which
+ *  writes the message to stderr and calls abort. This default handler can be
+ *  replaced at link time if the preprocessor macro
+ *  USE_EXTERNAL_DEFAULT_CALLBACKS is defined, which is the case if the build
+ *  has been configured with --enable-external-default-callbacks. Then the
+ *  following two symbols must be provided to link against:
+ *   - void secp256k1_default_illegal_callback_fn(const char* message, void* data);
+ *   - void secp256k1_default_error_callback_fn(const char* message, void* data);
+ *  The library can call these default handlers even before a proper callback data
+ *  pointer could have been set using secp256k1_context_set_illegal_callback or
+ *  secp256k1_context_set_error_callback, e.g., when the creation of a context
+ *  fails. In this case, the corresponding default handler will be called with
+ *  the data pointer argument set to NULL.
+ *
  *  Args: ctx:  an existing context object (cannot be NULL)
  *  In:   fun:  a pointer to a function to call when an illegal argument is
- *              passed to the API, taking a message and an opaque pointer
- *              (NULL restores a default handler that calls abort).
+ *              passed to the API, taking a message and an opaque pointer.
+ *              (NULL restores the default handler.)
  *        data: the opaque pointer to pass to fun above.
+ *
+ *  See also secp256k1_context_set_error_callback.
  */
 SECP256K1_API void secp256k1_context_set_illegal_callback(
     secp256k1_context* ctx,
@@ -224,9 +290,12 @@ SECP256K1_API void secp256k1_context_set_illegal_callback(
  *
  *  Args: ctx:  an existing context object (cannot be NULL)
  *  In:   fun:  a pointer to a function to call when an internal error occurs,
- *              taking a message and an opaque pointer (NULL restores a default
- *              handler that calls abort).
+ *              taking a message and an opaque pointer (NULL restores the
+ *              default handler, see secp256k1_context_set_illegal_callback
+ *              for details).
  *        data: the opaque pointer to pass to fun above.
+ *
+ *  See also secp256k1_context_set_illegal_callback.
  */
 SECP256K1_API void secp256k1_context_set_error_callback(
     secp256k1_context* ctx,
@@ -234,6 +303,29 @@ SECP256K1_API void secp256k1_context_set_error_callback(
     const void* data
 ) SECP256K1_ARG_NONNULL(1);
 
+/** Create a secp256k1 scratch space object.
+ *
+ *  Returns: a newly created scratch space.
+ *  Args: ctx:  an existing context object (cannot be NULL)
+ *  In:   size: amount of memory to be available as scratch space. Some extra
+ *              (<100 bytes) will be allocated for extra accounting.
+ */
+SECP256K1_API SECP256K1_WARN_UNUSED_RESULT secp256k1_scratch_space* secp256k1_scratch_space_create(
+    const secp256k1_context* ctx,
+    size_t size
+) SECP256K1_ARG_NONNULL(1);
+
+/** Destroy a secp256k1 scratch space.
+ *
+ *  The pointer may not be used afterwards.
+ *  Args:       ctx: a secp256k1 context object.
+ *          scratch: space to destroy
+ */
+SECP256K1_API void secp256k1_scratch_space_destroy(
+    const secp256k1_context* ctx,
+    secp256k1_scratch_space* scratch
+) SECP256K1_ARG_NONNULL(1);
+
 /** Parse a variable-length public key into the pubkey object.
  *
  *  Returns: 1 if the public key was fully valid.
@@ -439,7 +531,7 @@ SECP256K1_API extern const secp256k1_nonce_function secp256k1_nonce_function_def
 /** Create an ECDSA signature.
  *
  *  Returns: 1: signature created
- *           0: the nonce generation function failed, or the private key was invalid.
+ *           0: the nonce generation function failed, or the secret key was invalid.
  *  Args:    ctx:    pointer to a context object, initialized for signing (cannot be NULL)
  *  Out:     sig:    pointer to an array where the signature will be placed (cannot be NULL)
  *  In:      msg32:  the 32-byte message hash being signed (cannot be NULL)
@@ -460,6 +552,11 @@ SECP256K1_API int secp256k1_ecdsa_sign(
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3) SECP256K1_ARG_NONNULL(4);
 
 /** Verify an ECDSA secret key.
+ *
+ *  A secret key is valid if it is not 0 and less than the secp256k1 curve order
+ *  when interpreted as an integer (most significant byte first). The
+ *  probability of choosing a 32-byte string uniformly at random which is an
+ *  invalid secret key is negligible.
  *
  *  Returns: 1: secret key is valid
  *           0: secret key is invalid
@@ -477,7 +574,7 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_seckey_verify(
  *           0: secret was invalid, try again
  *  Args:   ctx:        pointer to a context object, initialized for signing (cannot be NULL)
  *  Out:    pubkey:     pointer to the created public key (cannot be NULL)
- *  In:     seckey:     pointer to a 32-byte private key (cannot be NULL)
+ *  In:     seckey:     pointer to a 32-byte secret key (cannot be NULL)
  */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_create(
     const secp256k1_context* ctx,
@@ -485,15 +582,63 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_create(
     const unsigned char *seckey
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
 
-/** Tweak a private key by adding tweak to it.
- * Returns: 0 if the tweak was out of range (chance of around 1 in 2^128 for
- *          uniformly random 32-byte arrays, or if the resulting private key
- *          would be invalid (only when the tweak is the complement of the
- *          private key). 1 otherwise.
- * Args:    ctx:    pointer to a context object (cannot be NULL).
- * In/Out:  seckey: pointer to a 32-byte private key.
- * In:      tweak:  pointer to a 32-byte tweak.
+/** Negates a secret key in place.
+ *
+ *  Returns: 0 if the given secret key is invalid according to
+ *           secp256k1_ec_seckey_verify. 1 otherwise
+ *  Args:   ctx:    pointer to a context object
+ *  In/Out: seckey: pointer to the 32-byte secret key to be negated. If the
+ *                  secret key is invalid according to
+ *                  secp256k1_ec_seckey_verify, this function returns 0 and
+ *                  seckey will be set to some unspecified value. (cannot be
+ *                  NULL)
  */
+SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_seckey_negate(
+    const secp256k1_context* ctx,
+    unsigned char *seckey
+) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2);
+
+/** Same as secp256k1_ec_seckey_negate, but DEPRECATED. Will be removed in
+ *  future versions. */
+SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_privkey_negate(
+    const secp256k1_context* ctx,
+    unsigned char *seckey
+) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2);
+
+/** Negates a public key in place.
+ *
+ *  Returns: 1 always
+ *  Args:   ctx:        pointer to a context object
+ *  In/Out: pubkey:     pointer to the public key to be negated (cannot be NULL)
+ */
+SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_negate(
+    const secp256k1_context* ctx,
+    secp256k1_pubkey *pubkey
+) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2);
+
+/** Tweak a secret key by adding tweak to it.
+ *
+ *  Returns: 0 if the arguments are invalid or the resulting secret key would be
+ *           invalid (only when the tweak is the negation of the secret key). 1
+ *           otherwise.
+ *  Args:    ctx:   pointer to a context object (cannot be NULL).
+ *  In/Out: seckey: pointer to a 32-byte secret key. If the secret key is
+ *                  invalid according to secp256k1_ec_seckey_verify, this
+ *                  function returns 0. seckey will be set to some unspecified
+ *                  value if this function returns 0. (cannot be NULL)
+ *  In:      tweak: pointer to a 32-byte tweak. If the tweak is invalid according to
+ *                  secp256k1_ec_seckey_verify, this function returns 0. For
+ *                  uniformly random 32-byte arrays the chance of being invalid
+ *                  is negligible (around 1 in 2^128) (cannot be NULL).
+ */
+SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_seckey_tweak_add(
+    const secp256k1_context* ctx,
+    unsigned char *seckey,
+    const unsigned char *tweak
+) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
+
+/** Same as secp256k1_ec_seckey_tweak_add, but DEPRECATED. Will be removed in
+ *  future versions. */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_privkey_tweak_add(
     const secp256k1_context* ctx,
     unsigned char *seckey,
@@ -501,14 +646,18 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_privkey_tweak_add(
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
 
 /** Tweak a public key by adding tweak times the generator to it.
- * Returns: 0 if the tweak was out of range (chance of around 1 in 2^128 for
- *          uniformly random 32-byte arrays, or if the resulting public key
- *          would be invalid (only when the tweak is the complement of the
- *          corresponding private key). 1 otherwise.
- * Args:    ctx:    pointer to a context object initialized for validation
+ *
+ *  Returns: 0 if the arguments are invalid or the resulting public key would be
+ *           invalid (only when the tweak is the negation of the corresponding
+ *           secret key). 1 otherwise.
+ *  Args:    ctx:   pointer to a context object initialized for validation
  *                  (cannot be NULL).
- * In/Out:  pubkey: pointer to a public key object.
- * In:      tweak:  pointer to a 32-byte tweak.
+ *  In/Out: pubkey: pointer to a public key object. pubkey will be set to an
+ *                  invalid value if this function returns 0 (cannot be NULL).
+ *  In:      tweak: pointer to a 32-byte tweak. If the tweak is invalid according to
+ *                  secp256k1_ec_seckey_verify, this function returns 0. For
+ *                  uniformly random 32-byte arrays the chance of being invalid
+ *                  is negligible (around 1 in 2^128) (cannot be NULL).
  */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_tweak_add(
     const secp256k1_context* ctx,
@@ -516,13 +665,27 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_tweak_add(
     const unsigned char *tweak
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
 
-/** Tweak a private key by multiplying it by a tweak.
- * Returns: 0 if the tweak was out of range (chance of around 1 in 2^128 for
- *          uniformly random 32-byte arrays, or equal to zero. 1 otherwise.
- * Args:   ctx:    pointer to a context object (cannot be NULL).
- * In/Out: seckey: pointer to a 32-byte private key.
- * In:     tweak:  pointer to a 32-byte tweak.
+/** Tweak a secret key by multiplying it by a tweak.
+ *
+ *  Returns: 0 if the arguments are invalid. 1 otherwise.
+ *  Args:   ctx:    pointer to a context object (cannot be NULL).
+ *  In/Out: seckey: pointer to a 32-byte secret key. If the secret key is
+ *                  invalid according to secp256k1_ec_seckey_verify, this
+ *                  function returns 0. seckey will be set to some unspecified
+ *                  value if this function returns 0. (cannot be NULL)
+ *  In:      tweak: pointer to a 32-byte tweak. If the tweak is invalid according to
+ *                  secp256k1_ec_seckey_verify, this function returns 0. For
+ *                  uniformly random 32-byte arrays the chance of being invalid
+ *                  is negligible (around 1 in 2^128) (cannot be NULL).
  */
+SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_seckey_tweak_mul(
+    const secp256k1_context* ctx,
+    unsigned char *seckey,
+    const unsigned char *tweak
+) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
+
+/** Same as secp256k1_ec_seckey_tweak_mul, but DEPRECATED. Will be removed in
+ *  future versions. */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_privkey_tweak_mul(
     const secp256k1_context* ctx,
     unsigned char *seckey,
@@ -530,12 +693,16 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_privkey_tweak_mul(
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
 
 /** Tweak a public key by multiplying it by a tweak value.
- * Returns: 0 if the tweak was out of range (chance of around 1 in 2^128 for
- *          uniformly random 32-byte arrays, or equal to zero. 1 otherwise.
- * Args:    ctx:    pointer to a context object initialized for validation
- *                 (cannot be NULL).
- * In/Out:  pubkey: pointer to a public key obkect.
- * In:      tweak:  pointer to a 32-byte tweak.
+ *
+ *  Returns: 0 if the arguments are invalid. 1 otherwise.
+ *  Args:    ctx:   pointer to a context object initialized for validation
+ *                  (cannot be NULL).
+ *  In/Out: pubkey: pointer to a public key object. pubkey will be set to an
+ *                  invalid value if this function returns 0 (cannot be NULL).
+ *  In:      tweak: pointer to a 32-byte tweak. If the tweak is invalid according to
+ *                  secp256k1_ec_seckey_verify, this function returns 0. For
+ *                  uniformly random 32-byte arrays the chance of being invalid
+ *                  is negligible (around 1 in 2^128) (cannot be NULL).
  */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_tweak_mul(
     const secp256k1_context* ctx,
@@ -543,11 +710,30 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_tweak_mul(
     const unsigned char *tweak
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
 
-/** Updates the context randomization.
- *  Returns: 1: randomization successfully updated
+/** Updates the context randomization to protect against side-channel leakage.
+ *  Returns: 1: randomization successfully updated or nothing to randomize
  *           0: error
  *  Args:    ctx:       pointer to a context object (cannot be NULL)
  *  In:      seed32:    pointer to a 32-byte random seed (NULL resets to initial state)
+ *
+ * While secp256k1 code is written to be constant-time no matter what secret
+ * values are, it's possible that a future compiler may output code which isn't,
+ * and also that the CPU may not emit the same radio frequencies or draw the same
+ * amount power for all values.
+ *
+ * This function provides a seed which is combined into the blinding value: that
+ * blinding value is added before each multiplication (and removed afterwards) so
+ * that it does not affect function results, but shields against attacks which
+ * rely on any input-dependent behaviour.
+ *
+ * This function has currently an effect only on contexts initialized for signing
+ * because randomization is currently used only for signing. However, this is not
+ * guaranteed and may change in the future. It is safe to call this function on
+ * contexts not initialized for signing; then it will have no effect and return 1.
+ *
+ * You should call this after secp256k1_context_create or
+ * secp256k1_context_clone (and secp256k1_context_preallocated_create or
+ * secp256k1_context_clone, resp.), and you may call this repeatedly afterwards.
  */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_context_randomize(
     secp256k1_context* ctx,
@@ -555,6 +741,7 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_context_randomize(
 ) SECP256K1_ARG_NONNULL(1);
 
 /** Add a number of public keys together.
+ *
  *  Returns: 1: the sum of the public keys is valid.
  *           0: the sum of the public keys is not valid.
  *  Args:   ctx:        pointer to a context object
@@ -570,8 +757,8 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ec_pubkey_combine(
     size_t n
 ) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3);
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 }
-# endif
-
 #endif
+
+#endif /* SECP256K1_H */
diff --git a/crypto/secp256k1/libsecp256k1/include/secp256k1_ecdh.h b/crypto/secp256k1/libsecp256k1/include/secp256k1_ecdh.h
index 4b84d7a96..4058e9c04 100644
--- a/crypto/secp256k1/libsecp256k1/include/secp256k1_ecdh.h
+++ b/crypto/secp256k1/libsecp256k1/include/secp256k1_ecdh.h
@@ -1,31 +1,62 @@
-#ifndef _SECP256K1_ECDH_
-# define _SECP256K1_ECDH_
+#ifndef SECP256K1_ECDH_H
+#define SECP256K1_ECDH_H
 
-# include "secp256k1.h"
+#include "secp256k1.h"
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 extern "C" {
-# endif
+#endif
+
+/** A pointer to a function that hashes an EC point to obtain an ECDH secret
+ *
+ *  Returns: 1 if the point was successfully hashed.
+ *           0 will cause secp256k1_ecdh to fail and return 0.
+ *           Other return values are not allowed, and the behaviour of
+ *           secp256k1_ecdh is undefined for other return values.
+ *  Out:     output:     pointer to an array to be filled by the function
+ *  In:      x32:        pointer to a 32-byte x coordinate
+ *           y32:        pointer to a 32-byte y coordinate
+ *           data:       arbitrary data pointer that is passed through
+ */
+typedef int (*secp256k1_ecdh_hash_function)(
+  unsigned char *output,
+  const unsigned char *x32,
+  const unsigned char *y32,
+  void *data
+);
+
+/** An implementation of SHA256 hash function that applies to compressed public key.
+ * Populates the output parameter with 32 bytes. */
+SECP256K1_API extern const secp256k1_ecdh_hash_function secp256k1_ecdh_hash_function_sha256;
+
+/** A default ECDH hash function (currently equal to secp256k1_ecdh_hash_function_sha256).
+ * Populates the output parameter with 32 bytes. */
+SECP256K1_API extern const secp256k1_ecdh_hash_function secp256k1_ecdh_hash_function_default;
 
 /** Compute an EC Diffie-Hellman secret in constant time
+ *
  *  Returns: 1: exponentiation was successful
- *           0: scalar was invalid (zero or overflow)
+ *           0: scalar was invalid (zero or overflow) or hashfp returned 0
  *  Args:    ctx:        pointer to a context object (cannot be NULL)
- *  Out:     result:     a 32-byte array which will be populated by an ECDH
- *                       secret computed from the point and scalar
+ *  Out:     output:     pointer to an array to be filled by hashfp
  *  In:      pubkey:     a pointer to a secp256k1_pubkey containing an
  *                       initialized public key
- *           privkey:    a 32-byte scalar with which to multiply the point
+ *           seckey:     a 32-byte scalar with which to multiply the point
+ *           hashfp:     pointer to a hash function. If NULL, secp256k1_ecdh_hash_function_sha256 is used
+ *                       (in which case, 32 bytes will be written to output)
+ *           data:       arbitrary data pointer that is passed through to hashfp
  */
 SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ecdh(
   const secp256k1_context* ctx,
-  unsigned char *result,
+  unsigned char *output,
   const secp256k1_pubkey *pubkey,
-  const unsigned char *privkey
+  const unsigned char *seckey,
+  secp256k1_ecdh_hash_function hashfp,
+  void *data
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3) SECP256K1_ARG_NONNULL(4);
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 }
-# endif
-
 #endif
+
+#endif /* SECP256K1_ECDH_H */
diff --git a/crypto/secp256k1/libsecp256k1/include/secp256k1_preallocated.h b/crypto/secp256k1/libsecp256k1/include/secp256k1_preallocated.h
new file mode 100644
index 000000000..a9ae15d5a
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/include/secp256k1_preallocated.h
@@ -0,0 +1,128 @@
+#ifndef SECP256K1_PREALLOCATED_H
+#define SECP256K1_PREALLOCATED_H
+
+#include "secp256k1.h"
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+/* The module provided by this header file is intended for settings in which it
+ * is not possible or desirable to rely on dynamic memory allocation. It provides
+ * functions for creating, cloning, and destroying secp256k1 context objects in a
+ * contiguous fixed-size block of memory provided by the caller.
+ *
+ * Context objects created by functions in this module can be used like contexts
+ * objects created by functions in secp256k1.h, i.e., they can be passed to any
+ * API function that expects a context object (see secp256k1.h for details). The
+ * only exception is that context objects created by functions in this module
+ * must be destroyed using secp256k1_context_preallocated_destroy (in this
+ * module) instead of secp256k1_context_destroy (in secp256k1.h).
+ *
+ * It is guaranteed that functions in this module will not call malloc or its
+ * friends realloc, calloc, and free.
+ */
+
+/** Determine the memory size of a secp256k1 context object to be created in
+ *  caller-provided memory.
+ *
+ *  The purpose of this function is to determine how much memory must be provided
+ *  to secp256k1_context_preallocated_create.
+ *
+ *  Returns: the required size of the caller-provided memory block
+ *  In:      flags:    which parts of the context to initialize.
+ */
+SECP256K1_API size_t secp256k1_context_preallocated_size(
+    unsigned int flags
+) SECP256K1_WARN_UNUSED_RESULT;
+
+/** Create a secp256k1 context object in caller-provided memory.
+ *
+ *  The caller must provide a pointer to a rewritable contiguous block of memory
+ *  of size at least secp256k1_context_preallocated_size(flags) bytes, suitably
+ *  aligned to hold an object of any type.
+ *
+ *  The block of memory is exclusively owned by the created context object during
+ *  the lifetime of this context object, which begins with the call to this
+ *  function and ends when a call to secp256k1_context_preallocated_destroy
+ *  (which destroys the context object again) returns. During the lifetime of the
+ *  context object, the caller is obligated not to access this block of memory,
+ *  i.e., the caller may not read or write the memory, e.g., by copying the memory
+ *  contents to a different location or trying to create a second context object
+ *  in the memory. In simpler words, the prealloc pointer (or any pointer derived
+ *  from it) should not be used during the lifetime of the context object.
+ *
+ *  Returns: a newly created context object.
+ *  In:      prealloc: a pointer to a rewritable contiguous block of memory of
+ *                     size at least secp256k1_context_preallocated_size(flags)
+ *                     bytes, as detailed above (cannot be NULL)
+ *           flags:    which parts of the context to initialize.
+ *
+ *  See also secp256k1_context_randomize (in secp256k1.h)
+ *  and secp256k1_context_preallocated_destroy.
+ */
+SECP256K1_API secp256k1_context* secp256k1_context_preallocated_create(
+    void* prealloc,
+    unsigned int flags
+) SECP256K1_ARG_NONNULL(1) SECP256K1_WARN_UNUSED_RESULT;
+
+/** Determine the memory size of a secp256k1 context object to be copied into
+ *  caller-provided memory.
+ *
+ *  Returns: the required size of the caller-provided memory block.
+ *  In:      ctx: an existing context to copy (cannot be NULL)
+ */
+SECP256K1_API size_t secp256k1_context_preallocated_clone_size(
+    const secp256k1_context* ctx
+) SECP256K1_ARG_NONNULL(1) SECP256K1_WARN_UNUSED_RESULT;
+
+/** Copy a secp256k1 context object into caller-provided memory.
+ *
+ *  The caller must provide a pointer to a rewritable contiguous block of memory
+ *  of size at least secp256k1_context_preallocated_size(flags) bytes, suitably
+ *  aligned to hold an object of any type.
+ *
+ *  The block of memory is exclusively owned by the created context object during
+ *  the lifetime of this context object, see the description of
+ *  secp256k1_context_preallocated_create for details.
+ *
+ *  Returns: a newly created context object.
+ *  Args:    ctx:      an existing context to copy (cannot be NULL)
+ *  In:      prealloc: a pointer to a rewritable contiguous block of memory of
+ *                     size at least secp256k1_context_preallocated_size(flags)
+ *                     bytes, as detailed above (cannot be NULL)
+ */
+SECP256K1_API secp256k1_context* secp256k1_context_preallocated_clone(
+    const secp256k1_context* ctx,
+    void* prealloc
+) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_WARN_UNUSED_RESULT;
+
+/** Destroy a secp256k1 context object that has been created in
+ *  caller-provided memory.
+ *
+ *  The context pointer may not be used afterwards.
+ *
+ *  The context to destroy must have been created using
+ *  secp256k1_context_preallocated_create or secp256k1_context_preallocated_clone.
+ *  If the context has instead been created using secp256k1_context_create or
+ *  secp256k1_context_clone, the behaviour is undefined. In that case,
+ *  secp256k1_context_destroy must be used instead.
+ *
+ *  If required, it is the responsibility of the caller to deallocate the block
+ *  of memory properly after this function returns, e.g., by calling free on the
+ *  preallocated pointer given to secp256k1_context_preallocated_create or
+ *  secp256k1_context_preallocated_clone.
+ *
+ *  Args:   ctx: an existing context to destroy, constructed using
+ *               secp256k1_context_preallocated_create or
+ *               secp256k1_context_preallocated_clone (cannot be NULL)
+ */
+SECP256K1_API void secp256k1_context_preallocated_destroy(
+    secp256k1_context* ctx
+);
+
+#ifdef __cplusplus
+}
+#endif
+
+#endif /* SECP256K1_PREALLOCATED_H */
diff --git a/crypto/secp256k1/libsecp256k1/include/secp256k1_recovery.h b/crypto/secp256k1/libsecp256k1/include/secp256k1_recovery.h
index 055379725..f8ccaecd3 100644
--- a/crypto/secp256k1/libsecp256k1/include/secp256k1_recovery.h
+++ b/crypto/secp256k1/libsecp256k1/include/secp256k1_recovery.h
@@ -1,11 +1,11 @@
-#ifndef _SECP256K1_RECOVERY_
-# define _SECP256K1_RECOVERY_
+#ifndef SECP256K1_RECOVERY_H
+#define SECP256K1_RECOVERY_H
 
-# include "secp256k1.h"
+#include "secp256k1.h"
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 extern "C" {
-# endif
+#endif
 
 /** Opaque data structured that holds a parsed ECDSA signature,
  *  supporting pubkey recovery.
@@ -70,7 +70,7 @@ SECP256K1_API int secp256k1_ecdsa_recoverable_signature_serialize_compact(
 /** Create a recoverable ECDSA signature.
  *
  *  Returns: 1: signature created
- *           0: the nonce generation function failed, or the private key was invalid.
+ *           0: the nonce generation function failed, or the secret key was invalid.
  *  Args:    ctx:    pointer to a context object, initialized for signing (cannot be NULL)
  *  Out:     sig:    pointer to an array where the signature will be placed (cannot be NULL)
  *  In:      msg32:  the 32-byte message hash being signed (cannot be NULL)
@@ -103,8 +103,8 @@ SECP256K1_API SECP256K1_WARN_UNUSED_RESULT int secp256k1_ecdsa_recover(
     const unsigned char *msg32
 ) SECP256K1_ARG_NONNULL(1) SECP256K1_ARG_NONNULL(2) SECP256K1_ARG_NONNULL(3) SECP256K1_ARG_NONNULL(4);
 
-# ifdef __cplusplus
+#ifdef __cplusplus
 }
-# endif
-
 #endif
+
+#endif /* SECP256K1_RECOVERY_H */
diff --git a/crypto/secp256k1/libsecp256k1/libsecp256k1.pc.in b/crypto/secp256k1/libsecp256k1/libsecp256k1.pc.in
index a0d006f11..694e98eef 100644
--- a/crypto/secp256k1/libsecp256k1/libsecp256k1.pc.in
+++ b/crypto/secp256k1/libsecp256k1/libsecp256k1.pc.in
@@ -8,6 +8,6 @@ Description: Optimized C library for EC operations on curve secp256k1
 URL: https://github.com/bitcoin-core/secp256k1
 Version: @PACKAGE_VERSION@
 Cflags: -I${includedir}
-Libs.private: @SECP_LIBS@
 Libs: -L${libdir} -lsecp256k1
+Libs.private: @SECP_LIBS@
 
diff --git a/crypto/secp256k1/libsecp256k1/sage/group_prover.sage b/crypto/secp256k1/libsecp256k1/sage/group_prover.sage
index ab580c5b2..8521f0799 100644
--- a/crypto/secp256k1/libsecp256k1/sage/group_prover.sage
+++ b/crypto/secp256k1/libsecp256k1/sage/group_prover.sage
@@ -3,7 +3,7 @@
 # to independently set assumptions on input or intermediary variables.
 #
 # The general approach is:
-# * A constraint is a tuple of two sets of of symbolic expressions:
+# * A constraint is a tuple of two sets of symbolic expressions:
 #   the first of which are required to evaluate to zero, the second of which
 #   are required to evaluate to nonzero.
 #   - A constraint is said to be conflicting if any of its nonzero expressions
@@ -17,7 +17,7 @@
 #   - A constraint describing the requirements of the law, called "require"
 # * Implementations are transliterated into functions that operate as well on
 #   algebraic input points, and are called once per combination of branches
-#   exectured. Each execution returns:
+#   executed. Each execution returns:
 #   - A constraint describing the assumptions this implementation requires
 #     (such as Z1=1), called "assumeFormula"
 #   - A constraint describing the assumptions this specific branch requires,
diff --git a/crypto/secp256k1/libsecp256k1/src/asm/field_10x26_arm.s b/crypto/secp256k1/libsecp256k1/src/asm/field_10x26_arm.s
index 1e2d7ff96..9a5bd0672 100644
--- a/crypto/secp256k1/libsecp256k1/src/asm/field_10x26_arm.s
+++ b/crypto/secp256k1/libsecp256k1/src/asm/field_10x26_arm.s
@@ -11,20 +11,14 @@ Note:
 
 - To avoid unnecessary loads and make use of available registers, two
   'passes' have every time been interleaved, with the odd passes accumulating c' and d' 
-  which will be added to c and d respectively in the the even passes
+  which will be added to c and d respectively in the even passes
 
 */
 
 	.syntax unified
-	.arch armv7-a
 	@ eabi attributes - see readelf -A
-	.eabi_attribute 8, 1  @ Tag_ARM_ISA_use = yes
-	.eabi_attribute 9, 0  @ Tag_Thumb_ISA_use = no
-	.eabi_attribute 10, 0 @ Tag_FP_arch = none
 	.eabi_attribute 24, 1 @ Tag_ABI_align_needed = 8-byte
 	.eabi_attribute 25, 1 @ Tag_ABI_align_preserved = 8-byte, except leaf SP
-	.eabi_attribute 30, 2 @ Tag_ABI_optimization_goals = Aggressive Speed
-	.eabi_attribute 34, 1 @ Tag_CPU_unaligned_access = v6
 	.text
 
 	@ Field constants
diff --git a/crypto/secp256k1/libsecp256k1/src/basic-config.h b/crypto/secp256k1/libsecp256k1/src/basic-config.h
index c4c16eb7c..e9be39d4c 100644
--- a/crypto/secp256k1/libsecp256k1/src/basic-config.h
+++ b/crypto/secp256k1/libsecp256k1/src/basic-config.h
@@ -4,13 +4,16 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_BASIC_CONFIG_
-#define _SECP256K1_BASIC_CONFIG_
+#ifndef SECP256K1_BASIC_CONFIG_H
+#define SECP256K1_BASIC_CONFIG_H
 
 #ifdef USE_BASIC_CONFIG
 
 #undef USE_ASM_X86_64
+#undef USE_ECMULT_STATIC_PRECOMPUTATION
 #undef USE_ENDOMORPHISM
+#undef USE_EXTERNAL_ASM
+#undef USE_EXTERNAL_DEFAULT_CALLBACKS
 #undef USE_FIELD_10X26
 #undef USE_FIELD_5X52
 #undef USE_FIELD_INV_BUILTIN
@@ -21,12 +24,15 @@
 #undef USE_SCALAR_8X32
 #undef USE_SCALAR_INV_BUILTIN
 #undef USE_SCALAR_INV_NUM
+#undef ECMULT_WINDOW_SIZE
 
 #define USE_NUM_NONE 1
 #define USE_FIELD_INV_BUILTIN 1
 #define USE_SCALAR_INV_BUILTIN 1
 #define USE_FIELD_10X26 1
 #define USE_SCALAR_8X32 1
+#define ECMULT_WINDOW_SIZE 15
 
-#endif // USE_BASIC_CONFIG
-#endif // _SECP256K1_BASIC_CONFIG_
+#endif /* USE_BASIC_CONFIG */
+
+#endif /* SECP256K1_BASIC_CONFIG_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/bench.h b/crypto/secp256k1/libsecp256k1/src/bench.h
index 3a71b4aaf..9bfed903e 100644
--- a/crypto/secp256k1/libsecp256k1/src/bench.h
+++ b/crypto/secp256k1/libsecp256k1/src/bench.h
@@ -4,47 +4,90 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_BENCH_H_
-#define _SECP256K1_BENCH_H_
+#ifndef SECP256K1_BENCH_H
+#define SECP256K1_BENCH_H
 
+#include <stdint.h>
 #include <stdio.h>
-#include <math.h>
+#include <string.h>
 #include "sys/time.h"
 
-static double gettimedouble(void) {
+static int64_t gettime_i64(void) {
     struct timeval tv;
     gettimeofday(&tv, NULL);
-    return tv.tv_usec * 0.000001 + tv.tv_sec;
+    return (int64_t)tv.tv_usec + (int64_t)tv.tv_sec * 1000000LL;
 }
 
-void print_number(double x) {
-    double y = x;
-    int c = 0;
-    if (y < 0.0) {
-        y = -y;
+#define FP_EXP (6)
+#define FP_MULT (1000000LL)
+
+/* Format fixed point number. */
+void print_number(const int64_t x) {
+    int64_t x_abs, y;
+    int c, i, rounding;
+    size_t ptr;
+    char buffer[30];
+
+    if (x == INT64_MIN) {
+        /* Prevent UB. */
+        printf("ERR");
+        return;
     }
-    while (y < 100.0) {
-        y *= 10.0;
+    x_abs = x < 0 ? -x : x;
+
+    /* Determine how many decimals we want to show (more than FP_EXP makes no
+     * sense). */
+    y = x_abs;
+    c = 0;
+    while (y > 0LL && y < 100LL * FP_MULT && c < FP_EXP) {
+        y *= 10LL;
         c++;
     }
-    printf("%.*f", c, x);
+
+    /* Round to 'c' decimals. */
+    y = x_abs;
+    rounding = 0;
+    for (i = c; i < FP_EXP; ++i) {
+        rounding = (y % 10) >= 5;
+        y /= 10;
+    }
+    y += rounding;
+
+    /* Format and print the number. */
+    ptr = sizeof(buffer) - 1;
+    buffer[ptr] = 0;
+    if (c != 0) {
+        for (i = 0; i < c; ++i) {
+            buffer[--ptr] = '0' + (y % 10);
+            y /= 10;
+        }
+        buffer[--ptr] = '.';
+    }
+    do {
+        buffer[--ptr] = '0' + (y % 10);
+        y /= 10;
+    } while (y != 0);
+    if (x < 0) {
+        buffer[--ptr] = '-';
+    }
+    printf("%s", &buffer[ptr]);
 }
 
-void run_benchmark(char *name, void (*benchmark)(void*), void (*setup)(void*), void (*teardown)(void*), void* data, int count, int iter) {
+void run_benchmark(char *name, void (*benchmark)(void*, int), void (*setup)(void*), void (*teardown)(void*, int), void* data, int count, int iter) {
     int i;
-    double min = HUGE_VAL;
-    double sum = 0.0;
-    double max = 0.0;
+    int64_t min = INT64_MAX;
+    int64_t sum = 0;
+    int64_t max = 0;
     for (i = 0; i < count; i++) {
-        double begin, total;
+        int64_t begin, total;
         if (setup != NULL) {
             setup(data);
         }
-        begin = gettimedouble();
-        benchmark(data);
-        total = gettimedouble() - begin;
+        begin = gettime_i64();
+        benchmark(data, iter);
+        total = gettime_i64() - begin;
         if (teardown != NULL) {
-            teardown(data);
+            teardown(data, iter);
         }
         if (total < min) {
             min = total;
@@ -55,12 +98,36 @@ void run_benchmark(char *name, void (*benchmark)(void*), void (*setup)(void*), v
         sum += total;
     }
     printf("%s: min ", name);
-    print_number(min * 1000000.0 / iter);
+    print_number(min * FP_MULT / iter);
     printf("us / avg ");
-    print_number((sum / count) * 1000000.0 / iter);
+    print_number(((sum * FP_MULT) / count) / iter);
     printf("us / max ");
-    print_number(max * 1000000.0 / iter);
+    print_number(max * FP_MULT / iter);
     printf("us\n");
 }
 
-#endif
+int have_flag(int argc, char** argv, char *flag) {
+    char** argm = argv + argc;
+    argv++;
+    if (argv == argm) {
+        return 1;
+    }
+    while (argv != NULL && argv != argm) {
+        if (strcmp(*argv, flag) == 0) {
+            return 1;
+        }
+        argv++;
+    }
+    return 0;
+}
+
+int get_iters(int default_iters) {
+    char* env = getenv("SECP256K1_BENCH_ITERS");
+    if (env) {
+        return strtol(env, NULL, 0);
+    } else {
+        return default_iters;
+    }
+}
+
+#endif /* SECP256K1_BENCH_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_ecdh.c b/crypto/secp256k1/libsecp256k1/src/bench_ecdh.c
index cde5e2dbb..f099d3388 100644
--- a/crypto/secp256k1/libsecp256k1/src/bench_ecdh.c
+++ b/crypto/secp256k1/libsecp256k1/src/bench_ecdh.c
@@ -15,11 +15,11 @@ typedef struct {
     secp256k1_context *ctx;
     secp256k1_pubkey point;
     unsigned char scalar[32];
-} bench_ecdh_t;
+} bench_ecdh_data;
 
 static void bench_ecdh_setup(void* arg) {
     int i;
-    bench_ecdh_t *data = (bench_ecdh_t*)arg;
+    bench_ecdh_data *data = (bench_ecdh_data*)arg;
     const unsigned char point[] = {
         0x03,
         0x54, 0x94, 0xc1, 0x5d, 0x32, 0x09, 0x97, 0x06,
@@ -28,27 +28,32 @@ static void bench_ecdh_setup(void* arg) {
         0xa2, 0xba, 0xd1, 0x84, 0xf8, 0x83, 0xc6, 0x9f
     };
 
-    /* create a context with no capabilities */
-    data->ctx = secp256k1_context_create(SECP256K1_FLAGS_TYPE_CONTEXT);
     for (i = 0; i < 32; i++) {
         data->scalar[i] = i + 1;
     }
     CHECK(secp256k1_ec_pubkey_parse(data->ctx, &data->point, point, sizeof(point)) == 1);
 }
 
-static void bench_ecdh(void* arg) {
+static void bench_ecdh(void* arg, int iters) {
     int i;
     unsigned char res[32];
-    bench_ecdh_t *data = (bench_ecdh_t*)arg;
+    bench_ecdh_data *data = (bench_ecdh_data*)arg;
 
-    for (i = 0; i < 20000; i++) {
-        CHECK(secp256k1_ecdh(data->ctx, res, &data->point, data->scalar) == 1);
+    for (i = 0; i < iters; i++) {
+        CHECK(secp256k1_ecdh(data->ctx, res, &data->point, data->scalar, NULL, NULL) == 1);
     }
 }
 
 int main(void) {
-    bench_ecdh_t data;
+    bench_ecdh_data data;
+
+    int iters = get_iters(20000);
+
+    /* create a context with no capabilities */
+    data.ctx = secp256k1_context_create(SECP256K1_FLAGS_TYPE_CONTEXT);
+
+    run_benchmark("ecdh", bench_ecdh, bench_ecdh_setup, NULL, &data, 10, iters);
 
-    run_benchmark("ecdh", bench_ecdh, bench_ecdh_setup, NULL, &data, 10, 20000);
+    secp256k1_context_destroy(data.ctx);
     return 0;
 }
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_ecmult.c b/crypto/secp256k1/libsecp256k1/src/bench_ecmult.c
new file mode 100644
index 000000000..facd07ef3
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/src/bench_ecmult.c
@@ -0,0 +1,214 @@
+/**********************************************************************
+ * Copyright (c) 2017 Pieter Wuille                                   *
+ * Distributed under the MIT software license, see the accompanying   *
+ * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
+ **********************************************************************/
+#include <stdio.h>
+
+#include "include/secp256k1.h"
+
+#include "util.h"
+#include "hash_impl.h"
+#include "num_impl.h"
+#include "field_impl.h"
+#include "group_impl.h"
+#include "scalar_impl.h"
+#include "ecmult_impl.h"
+#include "bench.h"
+#include "secp256k1.c"
+
+#define POINTS 32768
+
+typedef struct {
+    /* Setup once in advance */
+    secp256k1_context* ctx;
+    secp256k1_scratch_space* scratch;
+    secp256k1_scalar* scalars;
+    secp256k1_ge* pubkeys;
+    secp256k1_scalar* seckeys;
+    secp256k1_gej* expected_output;
+    secp256k1_ecmult_multi_func ecmult_multi;
+
+    /* Changes per test */
+    size_t count;
+    int includes_g;
+
+    /* Changes per test iteration */
+    size_t offset1;
+    size_t offset2;
+
+    /* Test output. */
+    secp256k1_gej* output;
+} bench_data;
+
+static int bench_callback(secp256k1_scalar* sc, secp256k1_ge* ge, size_t idx, void* arg) {
+    bench_data* data = (bench_data*)arg;
+    if (data->includes_g) ++idx;
+    if (idx == 0) {
+        *sc = data->scalars[data->offset1];
+        *ge = secp256k1_ge_const_g;
+    } else {
+        *sc = data->scalars[(data->offset1 + idx) % POINTS];
+        *ge = data->pubkeys[(data->offset2 + idx - 1) % POINTS];
+    }
+    return 1;
+}
+
+static void bench_ecmult(void* arg, int iters) {
+    bench_data* data = (bench_data*)arg;
+
+    int includes_g = data->includes_g;
+    int iter;
+    int count = data->count;
+    iters = iters / data->count;
+
+    for (iter = 0; iter < iters; ++iter) {
+        data->ecmult_multi(&data->ctx->error_callback, &data->ctx->ecmult_ctx, data->scratch, &data->output[iter], data->includes_g ? &data->scalars[data->offset1] : NULL, bench_callback, arg, count - includes_g);
+        data->offset1 = (data->offset1 + count) % POINTS;
+        data->offset2 = (data->offset2 + count - 1) % POINTS;
+    }
+}
+
+static void bench_ecmult_setup(void* arg) {
+    bench_data* data = (bench_data*)arg;
+    data->offset1 = (data->count * 0x537b7f6f + 0x8f66a481) % POINTS;
+    data->offset2 = (data->count * 0x7f6f537b + 0x6a1a8f49) % POINTS;
+}
+
+static void bench_ecmult_teardown(void* arg, int iters) {
+    bench_data* data = (bench_data*)arg;
+    int iter;
+    iters = iters / data->count;
+    /* Verify the results in teardown, to avoid doing comparisons while benchmarking. */
+    for (iter = 0; iter < iters; ++iter) {
+        secp256k1_gej tmp;
+        secp256k1_gej_add_var(&tmp, &data->output[iter], &data->expected_output[iter], NULL);
+        CHECK(secp256k1_gej_is_infinity(&tmp));
+    }
+}
+
+static void generate_scalar(uint32_t num, secp256k1_scalar* scalar) {
+    secp256k1_sha256 sha256;
+    unsigned char c[11] = {'e', 'c', 'm', 'u', 'l', 't', 0, 0, 0, 0};
+    unsigned char buf[32];
+    int overflow = 0;
+    c[6] = num;
+    c[7] = num >> 8;
+    c[8] = num >> 16;
+    c[9] = num >> 24;
+    secp256k1_sha256_initialize(&sha256);
+    secp256k1_sha256_write(&sha256, c, sizeof(c));
+    secp256k1_sha256_finalize(&sha256, buf);
+    secp256k1_scalar_set_b32(scalar, buf, &overflow);
+    CHECK(!overflow);
+}
+
+static void run_test(bench_data* data, size_t count, int includes_g, int num_iters) {
+    char str[32];
+    static const secp256k1_scalar zero = SECP256K1_SCALAR_CONST(0, 0, 0, 0, 0, 0, 0, 0);
+    size_t iters = 1 + num_iters / count;
+    size_t iter;
+
+    data->count = count;
+    data->includes_g = includes_g;
+
+    /* Compute (the negation of) the expected results directly. */
+    data->offset1 = (data->count * 0x537b7f6f + 0x8f66a481) % POINTS;
+    data->offset2 = (data->count * 0x7f6f537b + 0x6a1a8f49) % POINTS;
+    for (iter = 0; iter < iters; ++iter) {
+        secp256k1_scalar tmp;
+        secp256k1_scalar total = data->scalars[(data->offset1++) % POINTS];
+        size_t i = 0;
+        for (i = 0; i + 1 < count; ++i) {
+            secp256k1_scalar_mul(&tmp, &data->seckeys[(data->offset2++) % POINTS], &data->scalars[(data->offset1++) % POINTS]);
+            secp256k1_scalar_add(&total, &total, &tmp);
+        }
+        secp256k1_scalar_negate(&total, &total);
+        secp256k1_ecmult(&data->ctx->ecmult_ctx, &data->expected_output[iter], NULL, &zero, &total);
+    }
+
+    /* Run the benchmark. */
+    sprintf(str, includes_g ? "ecmult_%ig" : "ecmult_%i", (int)count);
+    run_benchmark(str, bench_ecmult, bench_ecmult_setup, bench_ecmult_teardown, data, 10, count * iters);
+}
+
+int main(int argc, char **argv) {
+    bench_data data;
+    int i, p;
+    secp256k1_gej* pubkeys_gej;
+    size_t scratch_size;
+
+    int iters = get_iters(10000);
+
+    data.ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
+    scratch_size = secp256k1_strauss_scratch_size(POINTS) + STRAUSS_SCRATCH_OBJECTS*16;
+    data.scratch = secp256k1_scratch_space_create(data.ctx, scratch_size);
+    data.ecmult_multi = secp256k1_ecmult_multi_var;
+
+    if (argc > 1) {
+        if(have_flag(argc, argv, "pippenger_wnaf")) {
+            printf("Using pippenger_wnaf:\n");
+            data.ecmult_multi = secp256k1_ecmult_pippenger_batch_single;
+        } else if(have_flag(argc, argv, "strauss_wnaf")) {
+            printf("Using strauss_wnaf:\n");
+            data.ecmult_multi = secp256k1_ecmult_strauss_batch_single;
+        } else if(have_flag(argc, argv, "simple")) {
+            printf("Using simple algorithm:\n");
+            data.ecmult_multi = secp256k1_ecmult_multi_var;
+            secp256k1_scratch_space_destroy(data.ctx, data.scratch);
+            data.scratch = NULL;
+        } else {
+            fprintf(stderr, "%s: unrecognized argument '%s'.\n", argv[0], argv[1]);
+            fprintf(stderr, "Use 'pippenger_wnaf', 'strauss_wnaf', 'simple' or no argument to benchmark a combined algorithm.\n");
+            return 1;
+        }
+    }
+
+    /* Allocate stuff */
+    data.scalars = malloc(sizeof(secp256k1_scalar) * POINTS);
+    data.seckeys = malloc(sizeof(secp256k1_scalar) * POINTS);
+    data.pubkeys = malloc(sizeof(secp256k1_ge) * POINTS);
+    data.expected_output = malloc(sizeof(secp256k1_gej) * (iters + 1));
+    data.output = malloc(sizeof(secp256k1_gej) * (iters + 1));
+
+    /* Generate a set of scalars, and private/public keypairs. */
+    pubkeys_gej = malloc(sizeof(secp256k1_gej) * POINTS);
+    secp256k1_gej_set_ge(&pubkeys_gej[0], &secp256k1_ge_const_g);
+    secp256k1_scalar_set_int(&data.seckeys[0], 1);
+    for (i = 0; i < POINTS; ++i) {
+        generate_scalar(i, &data.scalars[i]);
+        if (i) {
+            secp256k1_gej_double_var(&pubkeys_gej[i], &pubkeys_gej[i - 1], NULL);
+            secp256k1_scalar_add(&data.seckeys[i], &data.seckeys[i - 1], &data.seckeys[i - 1]);
+        }
+    }
+    secp256k1_ge_set_all_gej_var(data.pubkeys, pubkeys_gej, POINTS);
+    free(pubkeys_gej);
+
+    for (i = 1; i <= 8; ++i) {
+        run_test(&data, i, 1, iters);
+    }
+
+    /* This is disabled with low count of iterations because the loop runs 77 times even with iters=1
+    * and the higher it goes the longer the computation takes(more points)
+    * So we don't run this benchmark with low iterations to prevent slow down */
+     if (iters > 2) {
+        for (p = 0; p <= 11; ++p) {
+            for (i = 9; i <= 16; ++i) {
+                run_test(&data, i << p, 1, iters);
+            }
+        }
+    }
+
+    if (data.scratch != NULL) {
+        secp256k1_scratch_space_destroy(data.ctx, data.scratch);
+    }
+    secp256k1_context_destroy(data.ctx);
+    free(data.scalars);
+    free(data.pubkeys);
+    free(data.seckeys);
+    free(data.output);
+    free(data.expected_output);
+
+    return(0);
+}
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_internal.c b/crypto/secp256k1/libsecp256k1/src/bench_internal.c
index 0809f77bd..20759127d 100644
--- a/crypto/secp256k1/libsecp256k1/src/bench_internal.c
+++ b/crypto/secp256k1/libsecp256k1/src/bench_internal.c
@@ -25,10 +25,10 @@ typedef struct {
     secp256k1_gej gej_x, gej_y;
     unsigned char data[64];
     int wnaf[256];
-} bench_inv_t;
+} bench_inv;
 
 void bench_setup(void* arg) {
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
     static const unsigned char init_x[32] = {
         0x02, 0x03, 0x05, 0x07, 0x0b, 0x0d, 0x11, 0x13,
@@ -56,327 +56,326 @@ void bench_setup(void* arg) {
     memcpy(data->data + 32, init_y, 32);
 }
 
-void bench_scalar_add(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_scalar_add(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 2000000; i++) {
-        secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
+    for (i = 0; i < iters; i++) {
+        j += secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
+    CHECK(j <= iters);
 }
 
-void bench_scalar_negate(void* arg) {
+void bench_scalar_negate(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 2000000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_scalar_negate(&data->scalar_x, &data->scalar_x);
     }
 }
 
-void bench_scalar_sqr(void* arg) {
+void bench_scalar_sqr(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_scalar_sqr(&data->scalar_x, &data->scalar_x);
     }
 }
 
-void bench_scalar_mul(void* arg) {
+void bench_scalar_mul(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_scalar_mul(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
 }
 
 #ifdef USE_ENDOMORPHISM
-void bench_scalar_split(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_scalar_split(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 20000; i++) {
-        secp256k1_scalar l, r;
-        secp256k1_scalar_split_lambda(&l, &r, &data->scalar_x);
-        secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
+    for (i = 0; i < iters; i++) {
+        secp256k1_scalar_split_lambda(&data->scalar_x, &data->scalar_y, &data->scalar_x);
+        j += secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
+    CHECK(j <= iters);
 }
 #endif
 
-void bench_scalar_inverse(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_scalar_inverse(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 2000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_scalar_inverse(&data->scalar_x, &data->scalar_x);
-        secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
+        j += secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
+    CHECK(j <= iters);
 }
 
-void bench_scalar_inverse_var(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_scalar_inverse_var(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 2000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_scalar_inverse_var(&data->scalar_x, &data->scalar_x);
-        secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
+        j += secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
+    CHECK(j <= iters);
 }
 
-void bench_field_normalize(void* arg) {
+void bench_field_normalize(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 2000000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_fe_normalize(&data->fe_x);
     }
 }
 
-void bench_field_normalize_weak(void* arg) {
+void bench_field_normalize_weak(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 2000000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_fe_normalize_weak(&data->fe_x);
     }
 }
 
-void bench_field_mul(void* arg) {
+void bench_field_mul(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_fe_mul(&data->fe_x, &data->fe_x, &data->fe_y);
     }
 }
 
-void bench_field_sqr(void* arg) {
+void bench_field_sqr(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_fe_sqr(&data->fe_x, &data->fe_x);
     }
 }
 
-void bench_field_inverse(void* arg) {
+void bench_field_inverse(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_fe_inv(&data->fe_x, &data->fe_x);
         secp256k1_fe_add(&data->fe_x, &data->fe_y);
     }
 }
 
-void bench_field_inverse_var(void* arg) {
+void bench_field_inverse_var(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_fe_inv_var(&data->fe_x, &data->fe_x);
         secp256k1_fe_add(&data->fe_x, &data->fe_y);
     }
 }
 
-void bench_field_sqrt(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_field_sqrt(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
+    secp256k1_fe t;
 
-    for (i = 0; i < 20000; i++) {
-        secp256k1_fe_sqrt(&data->fe_x, &data->fe_x);
+    for (i = 0; i < iters; i++) {
+        t = data->fe_x;
+        j += secp256k1_fe_sqrt(&data->fe_x, &t);
         secp256k1_fe_add(&data->fe_x, &data->fe_y);
     }
+    CHECK(j <= iters);
 }
 
-void bench_group_double_var(void* arg) {
+void bench_group_double_var(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_gej_double_var(&data->gej_x, &data->gej_x, NULL);
     }
 }
 
-void bench_group_add_var(void* arg) {
+void bench_group_add_var(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_gej_add_var(&data->gej_x, &data->gej_x, &data->gej_y, NULL);
     }
 }
 
-void bench_group_add_affine(void* arg) {
+void bench_group_add_affine(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_gej_add_ge(&data->gej_x, &data->gej_x, &data->ge_y);
     }
 }
 
-void bench_group_add_affine_var(void* arg) {
+void bench_group_add_affine_var(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 200000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_gej_add_ge_var(&data->gej_x, &data->gej_x, &data->ge_y, NULL);
     }
 }
 
-void bench_group_jacobi_var(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_group_jacobi_var(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 20000; i++) {
-        secp256k1_gej_has_quad_y_var(&data->gej_x);
+    for (i = 0; i < iters; i++) {
+        j += secp256k1_gej_has_quad_y_var(&data->gej_x);
     }
+    CHECK(j == iters);
 }
 
-void bench_ecmult_wnaf(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_ecmult_wnaf(void* arg, int iters) {
+    int i, bits = 0, overflow = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 20000; i++) {
-        secp256k1_ecmult_wnaf(data->wnaf, 256, &data->scalar_x, WINDOW_A);
-        secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
+    for (i = 0; i < iters; i++) {
+        bits += secp256k1_ecmult_wnaf(data->wnaf, 256, &data->scalar_x, WINDOW_A);
+        overflow += secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
+    CHECK(overflow >= 0);
+    CHECK(bits <= 256*iters);
 }
 
-void bench_wnaf_const(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_wnaf_const(void* arg, int iters) {
+    int i, bits = 0, overflow = 0;
+    bench_inv *data = (bench_inv*)arg;
 
-    for (i = 0; i < 20000; i++) {
-        secp256k1_wnaf_const(data->wnaf, data->scalar_x, WINDOW_A);
-        secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
+    for (i = 0; i < iters; i++) {
+        bits += secp256k1_wnaf_const(data->wnaf, &data->scalar_x, WINDOW_A, 256);
+        overflow += secp256k1_scalar_add(&data->scalar_x, &data->scalar_x, &data->scalar_y);
     }
+    CHECK(overflow >= 0);
+    CHECK(bits <= 256*iters);
 }
 
 
-void bench_sha256(void* arg) {
+void bench_sha256(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
-    secp256k1_sha256_t sha;
+    bench_inv *data = (bench_inv*)arg;
+    secp256k1_sha256 sha;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_sha256_initialize(&sha);
         secp256k1_sha256_write(&sha, data->data, 32);
         secp256k1_sha256_finalize(&sha, data->data);
     }
 }
 
-void bench_hmac_sha256(void* arg) {
+void bench_hmac_sha256(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
-    secp256k1_hmac_sha256_t hmac;
+    bench_inv *data = (bench_inv*)arg;
+    secp256k1_hmac_sha256 hmac;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_hmac_sha256_initialize(&hmac, data->data, 32);
         secp256k1_hmac_sha256_write(&hmac, data->data, 32);
         secp256k1_hmac_sha256_finalize(&hmac, data->data);
     }
 }
 
-void bench_rfc6979_hmac_sha256(void* arg) {
+void bench_rfc6979_hmac_sha256(void* arg, int iters) {
     int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
-    secp256k1_rfc6979_hmac_sha256_t rng;
+    bench_inv *data = (bench_inv*)arg;
+    secp256k1_rfc6979_hmac_sha256 rng;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_rfc6979_hmac_sha256_initialize(&rng, data->data, 64);
         secp256k1_rfc6979_hmac_sha256_generate(&rng, data->data, 32);
     }
 }
 
-void bench_context_verify(void* arg) {
+void bench_context_verify(void* arg, int iters) {
     int i;
     (void)arg;
-    for (i = 0; i < 20; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_context_destroy(secp256k1_context_create(SECP256K1_CONTEXT_VERIFY));
     }
 }
 
-void bench_context_sign(void* arg) {
+void bench_context_sign(void* arg, int iters) {
     int i;
     (void)arg;
-    for (i = 0; i < 200; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_context_destroy(secp256k1_context_create(SECP256K1_CONTEXT_SIGN));
     }
 }
 
 #ifndef USE_NUM_NONE
-void bench_num_jacobi(void* arg) {
-    int i;
-    bench_inv_t *data = (bench_inv_t*)arg;
+void bench_num_jacobi(void* arg, int iters) {
+    int i, j = 0;
+    bench_inv *data = (bench_inv*)arg;
     secp256k1_num nx, norder;
 
     secp256k1_scalar_get_num(&nx, &data->scalar_x);
     secp256k1_scalar_order_get_num(&norder);
     secp256k1_scalar_get_num(&norder, &data->scalar_y);
 
-    for (i = 0; i < 200000; i++) {
-        secp256k1_num_jacobi(&nx, &norder);
+    for (i = 0; i < iters; i++) {
+        j += secp256k1_num_jacobi(&nx, &norder);
     }
+    CHECK(j <= iters);
 }
 #endif
 
-int have_flag(int argc, char** argv, char *flag) {
-    char** argm = argv + argc;
-    argv++;
-    if (argv == argm) {
-        return 1;
-    }
-    while (argv != NULL && argv != argm) {
-        if (strcmp(*argv, flag) == 0) {
-            return 1;
-        }
-        argv++;
-    }
-    return 0;
-}
-
 int main(int argc, char **argv) {
-    bench_inv_t data;
-    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "add")) run_benchmark("scalar_add", bench_scalar_add, bench_setup, NULL, &data, 10, 2000000);
-    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "negate")) run_benchmark("scalar_negate", bench_scalar_negate, bench_setup, NULL, &data, 10, 2000000);
-    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "sqr")) run_benchmark("scalar_sqr", bench_scalar_sqr, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "mul")) run_benchmark("scalar_mul", bench_scalar_mul, bench_setup, NULL, &data, 10, 200000);
+    bench_inv data;
+    int iters = get_iters(20000);
+
+    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "add")) run_benchmark("scalar_add", bench_scalar_add, bench_setup, NULL, &data, 10, iters*100);
+    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "negate")) run_benchmark("scalar_negate", bench_scalar_negate, bench_setup, NULL, &data, 10, iters*100);
+    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "sqr")) run_benchmark("scalar_sqr", bench_scalar_sqr, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "mul")) run_benchmark("scalar_mul", bench_scalar_mul, bench_setup, NULL, &data, 10, iters*10);
 #ifdef USE_ENDOMORPHISM
-    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "split")) run_benchmark("scalar_split", bench_scalar_split, bench_setup, NULL, &data, 10, 20000);
+    if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "split")) run_benchmark("scalar_split", bench_scalar_split, bench_setup, NULL, &data, 10, iters);
 #endif
     if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "inverse")) run_benchmark("scalar_inverse", bench_scalar_inverse, bench_setup, NULL, &data, 10, 2000);
     if (have_flag(argc, argv, "scalar") || have_flag(argc, argv, "inverse")) run_benchmark("scalar_inverse_var", bench_scalar_inverse_var, bench_setup, NULL, &data, 10, 2000);
 
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "normalize")) run_benchmark("field_normalize", bench_field_normalize, bench_setup, NULL, &data, 10, 2000000);
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "normalize")) run_benchmark("field_normalize_weak", bench_field_normalize_weak, bench_setup, NULL, &data, 10, 2000000);
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "sqr")) run_benchmark("field_sqr", bench_field_sqr, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "mul")) run_benchmark("field_mul", bench_field_mul, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "inverse")) run_benchmark("field_inverse", bench_field_inverse, bench_setup, NULL, &data, 10, 20000);
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "inverse")) run_benchmark("field_inverse_var", bench_field_inverse_var, bench_setup, NULL, &data, 10, 20000);
-    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "sqrt")) run_benchmark("field_sqrt", bench_field_sqrt, bench_setup, NULL, &data, 10, 20000);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "normalize")) run_benchmark("field_normalize", bench_field_normalize, bench_setup, NULL, &data, 10, iters*100);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "normalize")) run_benchmark("field_normalize_weak", bench_field_normalize_weak, bench_setup, NULL, &data, 10, iters*100);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "sqr")) run_benchmark("field_sqr", bench_field_sqr, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "mul")) run_benchmark("field_mul", bench_field_mul, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "inverse")) run_benchmark("field_inverse", bench_field_inverse, bench_setup, NULL, &data, 10, iters);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "inverse")) run_benchmark("field_inverse_var", bench_field_inverse_var, bench_setup, NULL, &data, 10, iters);
+    if (have_flag(argc, argv, "field") || have_flag(argc, argv, "sqrt")) run_benchmark("field_sqrt", bench_field_sqrt, bench_setup, NULL, &data, 10, iters);
 
-    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "double")) run_benchmark("group_double_var", bench_group_double_var, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "add")) run_benchmark("group_add_var", bench_group_add_var, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "add")) run_benchmark("group_add_affine", bench_group_add_affine, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "add")) run_benchmark("group_add_affine_var", bench_group_add_affine_var, bench_setup, NULL, &data, 10, 200000);
-    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "jacobi")) run_benchmark("group_jacobi_var", bench_group_jacobi_var, bench_setup, NULL, &data, 10, 20000);
+    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "double")) run_benchmark("group_double_var", bench_group_double_var, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "add")) run_benchmark("group_add_var", bench_group_add_var, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "add")) run_benchmark("group_add_affine", bench_group_add_affine, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "add")) run_benchmark("group_add_affine_var", bench_group_add_affine_var, bench_setup, NULL, &data, 10, iters*10);
+    if (have_flag(argc, argv, "group") || have_flag(argc, argv, "jacobi")) run_benchmark("group_jacobi_var", bench_group_jacobi_var, bench_setup, NULL, &data, 10, iters);
 
-    if (have_flag(argc, argv, "ecmult") || have_flag(argc, argv, "wnaf")) run_benchmark("wnaf_const", bench_wnaf_const, bench_setup, NULL, &data, 10, 20000);
-    if (have_flag(argc, argv, "ecmult") || have_flag(argc, argv, "wnaf")) run_benchmark("ecmult_wnaf", bench_ecmult_wnaf, bench_setup, NULL, &data, 10, 20000);
+    if (have_flag(argc, argv, "ecmult") || have_flag(argc, argv, "wnaf")) run_benchmark("wnaf_const", bench_wnaf_const, bench_setup, NULL, &data, 10, iters);
+    if (have_flag(argc, argv, "ecmult") || have_flag(argc, argv, "wnaf")) run_benchmark("ecmult_wnaf", bench_ecmult_wnaf, bench_setup, NULL, &data, 10, iters);
 
-    if (have_flag(argc, argv, "hash") || have_flag(argc, argv, "sha256")) run_benchmark("hash_sha256", bench_sha256, bench_setup, NULL, &data, 10, 20000);
-    if (have_flag(argc, argv, "hash") || have_flag(argc, argv, "hmac")) run_benchmark("hash_hmac_sha256", bench_hmac_sha256, bench_setup, NULL, &data, 10, 20000);
-    if (have_flag(argc, argv, "hash") || have_flag(argc, argv, "rng6979")) run_benchmark("hash_rfc6979_hmac_sha256", bench_rfc6979_hmac_sha256, bench_setup, NULL, &data, 10, 20000);
+    if (have_flag(argc, argv, "hash") || have_flag(argc, argv, "sha256")) run_benchmark("hash_sha256", bench_sha256, bench_setup, NULL, &data, 10, iters);
+    if (have_flag(argc, argv, "hash") || have_flag(argc, argv, "hmac")) run_benchmark("hash_hmac_sha256", bench_hmac_sha256, bench_setup, NULL, &data, 10, iters);
+    if (have_flag(argc, argv, "hash") || have_flag(argc, argv, "rng6979")) run_benchmark("hash_rfc6979_hmac_sha256", bench_rfc6979_hmac_sha256, bench_setup, NULL, &data, 10, iters);
 
-    if (have_flag(argc, argv, "context") || have_flag(argc, argv, "verify")) run_benchmark("context_verify", bench_context_verify, bench_setup, NULL, &data, 10, 20);
-    if (have_flag(argc, argv, "context") || have_flag(argc, argv, "sign")) run_benchmark("context_sign", bench_context_sign, bench_setup, NULL, &data, 10, 200);
+    if (have_flag(argc, argv, "context") || have_flag(argc, argv, "verify")) run_benchmark("context_verify", bench_context_verify, bench_setup, NULL, &data, 10, 1 + iters/1000);
+    if (have_flag(argc, argv, "context") || have_flag(argc, argv, "sign")) run_benchmark("context_sign", bench_context_sign, bench_setup, NULL, &data, 10, 1 + iters/100);
 
 #ifndef USE_NUM_NONE
-    if (have_flag(argc, argv, "num") || have_flag(argc, argv, "jacobi")) run_benchmark("num_jacobi", bench_num_jacobi, bench_setup, NULL, &data, 10, 200000);
+    if (have_flag(argc, argv, "num") || have_flag(argc, argv, "jacobi")) run_benchmark("num_jacobi", bench_num_jacobi, bench_setup, NULL, &data, 10, iters*10);
 #endif
     return 0;
 }
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_recover.c b/crypto/secp256k1/libsecp256k1/src/bench_recover.c
index 6489378cc..e952ed121 100644
--- a/crypto/secp256k1/libsecp256k1/src/bench_recover.c
+++ b/crypto/secp256k1/libsecp256k1/src/bench_recover.c
@@ -13,15 +13,15 @@ typedef struct {
     secp256k1_context *ctx;
     unsigned char msg[32];
     unsigned char sig[64];
-} bench_recover_t;
+} bench_recover_data;
 
-void bench_recover(void* arg) {
+void bench_recover(void* arg, int iters) {
     int i;
-    bench_recover_t *data = (bench_recover_t*)arg;
+    bench_recover_data *data = (bench_recover_data*)arg;
     secp256k1_pubkey pubkey;
     unsigned char pubkeyc[33];
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         int j;
         size_t pubkeylen = 33;
         secp256k1_ecdsa_recoverable_signature sig;
@@ -38,7 +38,7 @@ void bench_recover(void* arg) {
 
 void bench_recover_setup(void* arg) {
     int i;
-    bench_recover_t *data = (bench_recover_t*)arg;
+    bench_recover_data *data = (bench_recover_data*)arg;
 
     for (i = 0; i < 32; i++) {
         data->msg[i] = 1 + i;
@@ -49,11 +49,13 @@ void bench_recover_setup(void* arg) {
 }
 
 int main(void) {
-    bench_recover_t data;
+    bench_recover_data data;
+
+    int iters = get_iters(20000);
 
     data.ctx = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);
 
-    run_benchmark("ecdsa_recover", bench_recover, bench_recover_setup, NULL, &data, 10, 20000);
+    run_benchmark("ecdsa_recover", bench_recover, bench_recover_setup, NULL, &data, 10, iters);
 
     secp256k1_context_destroy(data.ctx);
     return 0;
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_schnorr_verify.c b/crypto/secp256k1/libsecp256k1/src/bench_schnorr_verify.c
deleted file mode 100644
index 5f137dda2..000000000
--- a/crypto/secp256k1/libsecp256k1/src/bench_schnorr_verify.c
+++ /dev/null
@@ -1,73 +0,0 @@
-/**********************************************************************
- * Copyright (c) 2014 Pieter Wuille                                   *
- * Distributed under the MIT software license, see the accompanying   *
- * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
- **********************************************************************/
-
-#include <stdio.h>
-#include <string.h>
-
-#include "include/secp256k1.h"
-#include "include/secp256k1_schnorr.h"
-#include "util.h"
-#include "bench.h"
-
-typedef struct {
-    unsigned char key[32];
-    unsigned char sig[64];
-    unsigned char pubkey[33];
-    size_t pubkeylen;
-} benchmark_schnorr_sig_t;
-
-typedef struct {
-    secp256k1_context *ctx;
-    unsigned char msg[32];
-    benchmark_schnorr_sig_t sigs[64];
-    int numsigs;
-} benchmark_schnorr_verify_t;
-
-static void benchmark_schnorr_init(void* arg) {
-    int i, k;
-    benchmark_schnorr_verify_t* data = (benchmark_schnorr_verify_t*)arg;
-
-    for (i = 0; i < 32; i++) {
-        data->msg[i] = 1 + i;
-    }
-    for (k = 0; k < data->numsigs; k++) {
-        secp256k1_pubkey pubkey;
-        for (i = 0; i < 32; i++) {
-            data->sigs[k].key[i] = 33 + i + k;
-        }
-        secp256k1_schnorr_sign(data->ctx, data->sigs[k].sig, data->msg, data->sigs[k].key, NULL, NULL);
-        data->sigs[k].pubkeylen = 33;
-        CHECK(secp256k1_ec_pubkey_create(data->ctx, &pubkey, data->sigs[k].key));
-        CHECK(secp256k1_ec_pubkey_serialize(data->ctx, data->sigs[k].pubkey, &data->sigs[k].pubkeylen, &pubkey, SECP256K1_EC_COMPRESSED));
-    }
-}
-
-static void benchmark_schnorr_verify(void* arg) {
-    int i;
-    benchmark_schnorr_verify_t* data = (benchmark_schnorr_verify_t*)arg;
-
-    for (i = 0; i < 20000 / data->numsigs; i++) {
-        secp256k1_pubkey pubkey;
-        data->sigs[0].sig[(i >> 8) % 64] ^= (i & 0xFF);
-        CHECK(secp256k1_ec_pubkey_parse(data->ctx, &pubkey, data->sigs[0].pubkey, data->sigs[0].pubkeylen));
-        CHECK(secp256k1_schnorr_verify(data->ctx, data->sigs[0].sig, data->msg, &pubkey) == ((i & 0xFF) == 0));
-        data->sigs[0].sig[(i >> 8) % 64] ^= (i & 0xFF);
-    }
-}
-
-
-
-int main(void) {
-    benchmark_schnorr_verify_t data;
-
-    data.ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
-
-    data.numsigs = 1;
-    run_benchmark("schnorr_verify", benchmark_schnorr_verify, benchmark_schnorr_init, NULL, &data, 10, 20000);
-
-    secp256k1_context_destroy(data.ctx);
-    return 0;
-}
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_sign.c b/crypto/secp256k1/libsecp256k1/src/bench_sign.c
index ed7224d75..c6b2942cc 100644
--- a/crypto/secp256k1/libsecp256k1/src/bench_sign.c
+++ b/crypto/secp256k1/libsecp256k1/src/bench_sign.c
@@ -12,11 +12,11 @@ typedef struct {
     secp256k1_context* ctx;
     unsigned char msg[32];
     unsigned char key[32];
-} bench_sign_t;
+} bench_sign;
 
 static void bench_sign_setup(void* arg) {
     int i;
-    bench_sign_t *data = (bench_sign_t*)arg;
+    bench_sign *data = (bench_sign*)arg;
 
     for (i = 0; i < 32; i++) {
         data->msg[i] = i + 1;
@@ -26,12 +26,12 @@ static void bench_sign_setup(void* arg) {
     }
 }
 
-static void bench_sign(void* arg) {
+static void bench_sign_run(void* arg, int iters) {
     int i;
-    bench_sign_t *data = (bench_sign_t*)arg;
+    bench_sign *data = (bench_sign*)arg;
 
     unsigned char sig[74];
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         size_t siglen = 74;
         int j;
         secp256k1_ecdsa_signature signature;
@@ -45,11 +45,13 @@ static void bench_sign(void* arg) {
 }
 
 int main(void) {
-    bench_sign_t data;
+    bench_sign data;
+
+    int iters = get_iters(20000);
 
     data.ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
 
-    run_benchmark("ecdsa_sign", bench_sign, bench_sign_setup, NULL, &data, 10, 20000);
+    run_benchmark("ecdsa_sign", bench_sign_run, bench_sign_setup, NULL, &data, 10, iters);
 
     secp256k1_context_destroy(data.ctx);
     return 0;
diff --git a/crypto/secp256k1/libsecp256k1/src/bench_verify.c b/crypto/secp256k1/libsecp256k1/src/bench_verify.c
index 418defa0a..272d3e5cc 100644
--- a/crypto/secp256k1/libsecp256k1/src/bench_verify.c
+++ b/crypto/secp256k1/libsecp256k1/src/bench_verify.c
@@ -17,6 +17,7 @@
 #include <openssl/obj_mac.h>
 #endif
 
+
 typedef struct {
     secp256k1_context *ctx;
     unsigned char msg[32];
@@ -30,11 +31,11 @@ typedef struct {
 #endif
 } benchmark_verify_t;
 
-static void benchmark_verify(void* arg) {
+static void benchmark_verify(void* arg, int iters) {
     int i;
     benchmark_verify_t* data = (benchmark_verify_t*)arg;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         secp256k1_pubkey pubkey;
         secp256k1_ecdsa_signature sig;
         data->sig[data->siglen - 1] ^= (i & 0xFF);
@@ -50,11 +51,11 @@ static void benchmark_verify(void* arg) {
 }
 
 #ifdef ENABLE_OPENSSL_TESTS
-static void benchmark_verify_openssl(void* arg) {
+static void benchmark_verify_openssl(void* arg, int iters) {
     int i;
     benchmark_verify_t* data = (benchmark_verify_t*)arg;
 
-    for (i = 0; i < 20000; i++) {
+    for (i = 0; i < iters; i++) {
         data->sig[data->siglen - 1] ^= (i & 0xFF);
         data->sig[data->siglen - 2] ^= ((i >> 8) & 0xFF);
         data->sig[data->siglen - 3] ^= ((i >> 16) & 0xFF);
@@ -85,6 +86,8 @@ int main(void) {
     secp256k1_ecdsa_signature sig;
     benchmark_verify_t data;
 
+    int iters = get_iters(20000);
+
     data.ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
 
     for (i = 0; i < 32; i++) {
@@ -100,10 +103,10 @@ int main(void) {
     data.pubkeylen = 33;
     CHECK(secp256k1_ec_pubkey_serialize(data.ctx, data.pubkey, &data.pubkeylen, &pubkey, SECP256K1_EC_COMPRESSED) == 1);
 
-    run_benchmark("ecdsa_verify", benchmark_verify, NULL, NULL, &data, 10, 20000);
+    run_benchmark("ecdsa_verify", benchmark_verify, NULL, NULL, &data, 10, iters);
 #ifdef ENABLE_OPENSSL_TESTS
     data.ec_group = EC_GROUP_new_by_curve_name(NID_secp256k1);
-    run_benchmark("ecdsa_verify_openssl", benchmark_verify_openssl, NULL, NULL, &data, 10, 20000);
+    run_benchmark("ecdsa_verify_openssl", benchmark_verify_openssl, NULL, NULL, &data, 10, iters);
     EC_GROUP_free(data.ec_group);
 #endif
 
diff --git a/crypto/secp256k1/libsecp256k1/src/ecdsa.h b/crypto/secp256k1/libsecp256k1/src/ecdsa.h
index 54ae101b9..80590c7cc 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecdsa.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecdsa.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECDSA_
-#define _SECP256K1_ECDSA_
+#ifndef SECP256K1_ECDSA_H
+#define SECP256K1_ECDSA_H
 
 #include <stddef.h>
 
@@ -18,4 +18,4 @@ static int secp256k1_ecdsa_sig_serialize(unsigned char *sig, size_t *size, const
 static int secp256k1_ecdsa_sig_verify(const secp256k1_ecmult_context *ctx, const secp256k1_scalar* r, const secp256k1_scalar* s, const secp256k1_ge *pubkey, const secp256k1_scalar *message);
 static int secp256k1_ecdsa_sig_sign(const secp256k1_ecmult_gen_context *ctx, secp256k1_scalar* r, secp256k1_scalar* s, const secp256k1_scalar *seckey, const secp256k1_scalar *message, const secp256k1_scalar *nonce, int *recid);
 
-#endif
+#endif /* SECP256K1_ECDSA_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecdsa_impl.h b/crypto/secp256k1/libsecp256k1/src/ecdsa_impl.h
index 453bb1188..5f54b59fa 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecdsa_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecdsa_impl.h
@@ -5,8 +5,8 @@
  **********************************************************************/
 
 
-#ifndef _SECP256K1_ECDSA_IMPL_H_
-#define _SECP256K1_ECDSA_IMPL_H_
+#ifndef SECP256K1_ECDSA_IMPL_H
+#define SECP256K1_ECDSA_IMPL_H
 
 #include "scalar.h"
 #include "field.h"
@@ -46,70 +46,73 @@ static const secp256k1_fe secp256k1_ecdsa_const_p_minus_order = SECP256K1_FE_CON
     0, 0, 0, 1, 0x45512319UL, 0x50B75FC4UL, 0x402DA172UL, 0x2FC9BAEEUL
 );
 
-static int secp256k1_der_read_len(const unsigned char **sigp, const unsigned char *sigend) {
-    int lenleft, b1;
-    size_t ret = 0;
+static int secp256k1_der_read_len(size_t *len, const unsigned char **sigp, const unsigned char *sigend) {
+    size_t lenleft;
+    unsigned char b1;
+    VERIFY_CHECK(len != NULL);
+    *len = 0;
     if (*sigp >= sigend) {
-        return -1;
+        return 0;
     }
     b1 = *((*sigp)++);
     if (b1 == 0xFF) {
         /* X.690-0207 8.1.3.5.c the value 0xFF shall not be used. */
-        return -1;
+        return 0;
     }
     if ((b1 & 0x80) == 0) {
         /* X.690-0207 8.1.3.4 short form length octets */
-        return b1;
+        *len = b1;
+        return 1;
     }
     if (b1 == 0x80) {
         /* Indefinite length is not allowed in DER. */
-        return -1;
+        return 0;
     }
     /* X.690-207 8.1.3.5 long form length octets */
-    lenleft = b1 & 0x7F;
-    if (lenleft > sigend - *sigp) {
-        return -1;
+    lenleft = b1 & 0x7F; /* lenleft is at least 1 */
+    if (lenleft > (size_t)(sigend - *sigp)) {
+        return 0;
     }
     if (**sigp == 0) {
         /* Not the shortest possible length encoding. */
-        return -1;
+        return 0;
     }
-    if ((size_t)lenleft > sizeof(size_t)) {
+    if (lenleft > sizeof(size_t)) {
         /* The resulting length would exceed the range of a size_t, so
          * certainly longer than the passed array size.
          */
-        return -1;
+        return 0;
     }
     while (lenleft > 0) {
-        if ((ret >> ((sizeof(size_t) - 1) * 8)) != 0) {
-        }
-        ret = (ret << 8) | **sigp;
-        if (ret + lenleft > (size_t)(sigend - *sigp)) {
-            /* Result exceeds the length of the passed array. */
-            return -1;
-        }
+        *len = (*len << 8) | **sigp;
         (*sigp)++;
         lenleft--;
     }
-    if (ret < 128) {
+    if (*len > (size_t)(sigend - *sigp)) {
+        /* Result exceeds the length of the passed array. */
+        return 0;
+    }
+    if (*len < 128) {
         /* Not the shortest possible length encoding. */
-        return -1;
+        return 0;
     }
-    return ret;
+    return 1;
 }
 
 static int secp256k1_der_parse_integer(secp256k1_scalar *r, const unsigned char **sig, const unsigned char *sigend) {
     int overflow = 0;
     unsigned char ra[32] = {0};
-    int rlen;
+    size_t rlen;
 
     if (*sig == sigend || **sig != 0x02) {
         /* Not a primitive integer (X.690-0207 8.3.1). */
         return 0;
     }
     (*sig)++;
-    rlen = secp256k1_der_read_len(sig, sigend);
-    if (rlen <= 0 || (*sig) + rlen > sigend) {
+    if (secp256k1_der_read_len(&rlen, sig, sigend) == 0) {
+        return 0;
+    }
+    if (rlen == 0 || *sig + rlen > sigend) {
         /* Exceeds bounds or not at least length 1 (X.690-0207 8.3.1).  */
         return 0;
     }
@@ -125,8 +128,11 @@ static int secp256k1_der_parse_integer(secp256k1_scalar *r, const unsigned char
         /* Negative. */
         overflow = 1;
     }
-    while (rlen > 0 && **sig == 0) {
-        /* Skip leading zero bytes */
+    /* There is at most one leading zero byte:
+     * if there were two leading zero bytes, we would have failed and returned 0
+     * because of excessive 0x00 padding already. */
+    if (rlen > 0 && **sig == 0) {
+        /* Skip leading zero byte */
         rlen--;
         (*sig)++;
     }
@@ -146,18 +152,16 @@ static int secp256k1_der_parse_integer(secp256k1_scalar *r, const unsigned char
 
 static int secp256k1_ecdsa_sig_parse(secp256k1_scalar *rr, secp256k1_scalar *rs, const unsigned char *sig, size_t size) {
     const unsigned char *sigend = sig + size;
-    int rlen;
+    size_t rlen;
     if (sig == sigend || *(sig++) != 0x30) {
         /* The encoding doesn't start with a constructed sequence (X.690-0207 8.9.1). */
         return 0;
     }
-    rlen = secp256k1_der_read_len(&sig, sigend);
-    if (rlen < 0 || sig + rlen > sigend) {
-        /* Tuple exceeds bounds */
+    if (secp256k1_der_read_len(&rlen, &sig, sigend) == 0) {
         return 0;
     }
-    if (sig + rlen != sigend) {
-        /* Garbage after tuple. */
+    if (rlen != (size_t)(sigend - sig)) {
+        /* Tuple exceeds bounds or garage after tuple. */
         return 0;
     }
 
@@ -276,6 +280,7 @@ static int secp256k1_ecdsa_sig_sign(const secp256k1_ecmult_gen_context *ctx, sec
     secp256k1_ge r;
     secp256k1_scalar n;
     int overflow = 0;
+    int high;
 
     secp256k1_ecmult_gen(ctx, &rp, nonce);
     secp256k1_ge_set_gej(&r, &rp);
@@ -283,15 +288,11 @@ static int secp256k1_ecdsa_sig_sign(const secp256k1_ecmult_gen_context *ctx, sec
     secp256k1_fe_normalize(&r.y);
     secp256k1_fe_get_b32(b, &r.x);
     secp256k1_scalar_set_b32(sigr, b, &overflow);
-    /* These two conditions should be checked before calling */
-    VERIFY_CHECK(!secp256k1_scalar_is_zero(sigr));
-    VERIFY_CHECK(overflow == 0);
-
     if (recid) {
         /* The overflow condition is cryptographically unreachable as hitting it requires finding the discrete log
          * of some P where P.x >= order, and only 1 in about 2^127 points meet this criteria.
          */
-        *recid = (overflow ? 2 : 0) | (secp256k1_fe_is_odd(&r.y) ? 1 : 0);
+        *recid = (overflow << 1) | secp256k1_fe_is_odd(&r.y);
     }
     secp256k1_scalar_mul(&n, sigr, seckey);
     secp256k1_scalar_add(&n, &n, message);
@@ -300,16 +301,15 @@ static int secp256k1_ecdsa_sig_sign(const secp256k1_ecmult_gen_context *ctx, sec
     secp256k1_scalar_clear(&n);
     secp256k1_gej_clear(&rp);
     secp256k1_ge_clear(&r);
-    if (secp256k1_scalar_is_zero(sigs)) {
-        return 0;
-    }
-    if (secp256k1_scalar_is_high(sigs)) {
-        secp256k1_scalar_negate(sigs, sigs);
-        if (recid) {
-            *recid ^= 1;
-        }
+    high = secp256k1_scalar_is_high(sigs);
+    secp256k1_scalar_cond_negate(sigs, high);
+    if (recid) {
+            *recid ^= high;
     }
-    return 1;
+    /* P.x = order is on the curve, so technically sig->r could end up being zero, which would be an invalid signature.
+     * This is cryptographically unreachable as hitting it requires finding the discrete log of P.x = N.
+     */
+    return !secp256k1_scalar_is_zero(sigr) & !secp256k1_scalar_is_zero(sigs);
 }
 
-#endif
+#endif /* SECP256K1_ECDSA_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/eckey.h b/crypto/secp256k1/libsecp256k1/src/eckey.h
index 42739a3be..b621f1e6c 100644
--- a/crypto/secp256k1/libsecp256k1/src/eckey.h
+++ b/crypto/secp256k1/libsecp256k1/src/eckey.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECKEY_
-#define _SECP256K1_ECKEY_
+#ifndef SECP256K1_ECKEY_H
+#define SECP256K1_ECKEY_H
 
 #include <stddef.h>
 
@@ -22,4 +22,4 @@ static int secp256k1_eckey_pubkey_tweak_add(const secp256k1_ecmult_context *ctx,
 static int secp256k1_eckey_privkey_tweak_mul(secp256k1_scalar *key, const secp256k1_scalar *tweak);
 static int secp256k1_eckey_pubkey_tweak_mul(const secp256k1_ecmult_context *ctx, secp256k1_ge *key, const secp256k1_scalar *tweak);
 
-#endif
+#endif /* SECP256K1_ECKEY_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/eckey_impl.h b/crypto/secp256k1/libsecp256k1/src/eckey_impl.h
index ce38071ac..e2e72d930 100644
--- a/crypto/secp256k1/libsecp256k1/src/eckey_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/eckey_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECKEY_IMPL_H_
-#define _SECP256K1_ECKEY_IMPL_H_
+#ifndef SECP256K1_ECKEY_IMPL_H
+#define SECP256K1_ECKEY_IMPL_H
 
 #include "eckey.h"
 
@@ -15,16 +15,17 @@
 #include "ecmult_gen.h"
 
 static int secp256k1_eckey_pubkey_parse(secp256k1_ge *elem, const unsigned char *pub, size_t size) {
-    if (size == 33 && (pub[0] == 0x02 || pub[0] == 0x03)) {
+    if (size == 33 && (pub[0] == SECP256K1_TAG_PUBKEY_EVEN || pub[0] == SECP256K1_TAG_PUBKEY_ODD)) {
         secp256k1_fe x;
-        return secp256k1_fe_set_b32(&x, pub+1) && secp256k1_ge_set_xo_var(elem, &x, pub[0] == 0x03);
-    } else if (size == 65 && (pub[0] == 0x04 || pub[0] == 0x06 || pub[0] == 0x07)) {
+        return secp256k1_fe_set_b32(&x, pub+1) && secp256k1_ge_set_xo_var(elem, &x, pub[0] == SECP256K1_TAG_PUBKEY_ODD);
+    } else if (size == 65 && (pub[0] == SECP256K1_TAG_PUBKEY_UNCOMPRESSED || pub[0] == SECP256K1_TAG_PUBKEY_HYBRID_EVEN || pub[0] == SECP256K1_TAG_PUBKEY_HYBRID_ODD)) {
         secp256k1_fe x, y;
         if (!secp256k1_fe_set_b32(&x, pub+1) || !secp256k1_fe_set_b32(&y, pub+33)) {
             return 0;
         }
         secp256k1_ge_set_xy(elem, &x, &y);
-        if ((pub[0] == 0x06 || pub[0] == 0x07) && secp256k1_fe_is_odd(&y) != (pub[0] == 0x07)) {
+        if ((pub[0] == SECP256K1_TAG_PUBKEY_HYBRID_EVEN || pub[0] == SECP256K1_TAG_PUBKEY_HYBRID_ODD) &&
+            secp256k1_fe_is_odd(&y) != (pub[0] == SECP256K1_TAG_PUBKEY_HYBRID_ODD)) {
             return 0;
         }
         return secp256k1_ge_is_valid_var(elem);
@@ -42,10 +43,10 @@ static int secp256k1_eckey_pubkey_serialize(secp256k1_ge *elem, unsigned char *p
     secp256k1_fe_get_b32(&pub[1], &elem->x);
     if (compressed) {
         *size = 33;
-        pub[0] = 0x02 | (secp256k1_fe_is_odd(&elem->y) ? 0x01 : 0x00);
+        pub[0] = secp256k1_fe_is_odd(&elem->y) ? SECP256K1_TAG_PUBKEY_ODD : SECP256K1_TAG_PUBKEY_EVEN;
     } else {
         *size = 65;
-        pub[0] = 0x04;
+        pub[0] = SECP256K1_TAG_PUBKEY_UNCOMPRESSED;
         secp256k1_fe_get_b32(&pub[33], &elem->y);
     }
     return 1;
@@ -53,10 +54,7 @@ static int secp256k1_eckey_pubkey_serialize(secp256k1_ge *elem, unsigned char *p
 
 static int secp256k1_eckey_privkey_tweak_add(secp256k1_scalar *key, const secp256k1_scalar *tweak) {
     secp256k1_scalar_add(key, key, tweak);
-    if (secp256k1_scalar_is_zero(key)) {
-        return 0;
-    }
-    return 1;
+    return !secp256k1_scalar_is_zero(key);
 }
 
 static int secp256k1_eckey_pubkey_tweak_add(const secp256k1_ecmult_context *ctx, secp256k1_ge *key, const secp256k1_scalar *tweak) {
@@ -74,12 +72,11 @@ static int secp256k1_eckey_pubkey_tweak_add(const secp256k1_ecmult_context *ctx,
 }
 
 static int secp256k1_eckey_privkey_tweak_mul(secp256k1_scalar *key, const secp256k1_scalar *tweak) {
-    if (secp256k1_scalar_is_zero(tweak)) {
-        return 0;
-    }
+    int ret;
+    ret = !secp256k1_scalar_is_zero(tweak);
 
     secp256k1_scalar_mul(key, key, tweak);
-    return 1;
+    return ret;
 }
 
 static int secp256k1_eckey_pubkey_tweak_mul(const secp256k1_ecmult_context *ctx, secp256k1_ge *key, const secp256k1_scalar *tweak) {
@@ -96,4 +93,4 @@ static int secp256k1_eckey_pubkey_tweak_mul(const secp256k1_ecmult_context *ctx,
     return 1;
 }
 
-#endif
+#endif /* SECP256K1_ECKEY_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecmult.h b/crypto/secp256k1/libsecp256k1/src/ecmult.h
index 20484134f..c9b198239 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecmult.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecmult.h
@@ -1,14 +1,16 @@
 /**********************************************************************
- * Copyright (c) 2013, 2014 Pieter Wuille                             *
+ * Copyright (c) 2013, 2014, 2017 Pieter Wuille, Andrew Poelstra      *
  * Distributed under the MIT software license, see the accompanying   *
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECMULT_
-#define _SECP256K1_ECMULT_
+#ifndef SECP256K1_ECMULT_H
+#define SECP256K1_ECMULT_H
 
 #include "num.h"
 #include "group.h"
+#include "scalar.h"
+#include "scratch.h"
 
 typedef struct {
     /* For accelerating the computation of a*P + b*G: */
@@ -18,14 +20,29 @@ typedef struct {
 #endif
 } secp256k1_ecmult_context;
 
+static const size_t SECP256K1_ECMULT_CONTEXT_PREALLOCATED_SIZE;
 static void secp256k1_ecmult_context_init(secp256k1_ecmult_context *ctx);
-static void secp256k1_ecmult_context_build(secp256k1_ecmult_context *ctx, const secp256k1_callback *cb);
-static void secp256k1_ecmult_context_clone(secp256k1_ecmult_context *dst,
-                                           const secp256k1_ecmult_context *src, const secp256k1_callback *cb);
+static void secp256k1_ecmult_context_build(secp256k1_ecmult_context *ctx, void **prealloc);
+static void secp256k1_ecmult_context_finalize_memcpy(secp256k1_ecmult_context *dst, const secp256k1_ecmult_context *src);
 static void secp256k1_ecmult_context_clear(secp256k1_ecmult_context *ctx);
 static int secp256k1_ecmult_context_is_built(const secp256k1_ecmult_context *ctx);
 
 /** Double multiply: R = na*A + ng*G */
 static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej *r, const secp256k1_gej *a, const secp256k1_scalar *na, const secp256k1_scalar *ng);
 
-#endif
+typedef int (secp256k1_ecmult_multi_callback)(secp256k1_scalar *sc, secp256k1_ge *pt, size_t idx, void *data);
+
+/**
+ * Multi-multiply: R = inp_g_sc * G + sum_i ni * Ai.
+ * Chooses the right algorithm for a given number of points and scratch space
+ * size. Resets and overwrites the given scratch space. If the points do not
+ * fit in the scratch space the algorithm is repeatedly run with batches of
+ * points. If no scratch space is given then a simple algorithm is used that
+ * simply multiplies the points with the corresponding scalars and adds them up.
+ * Returns: 1 on success (including when inp_g_sc is NULL and n is 0)
+ *          0 if there is not enough scratch space for a single point or
+ *          callback returns 0
+ */
+static int secp256k1_ecmult_multi_var(const secp256k1_callback* error_callback, const secp256k1_ecmult_context *ctx, secp256k1_scratch *scratch, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n);
+
+#endif /* SECP256K1_ECMULT_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecmult_const.h b/crypto/secp256k1/libsecp256k1/src/ecmult_const.h
index 2b0097655..03bb33257 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecmult_const.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecmult_const.h
@@ -4,12 +4,17 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECMULT_CONST_
-#define _SECP256K1_ECMULT_CONST_
+#ifndef SECP256K1_ECMULT_CONST_H
+#define SECP256K1_ECMULT_CONST_H
 
 #include "scalar.h"
 #include "group.h"
 
-static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, const secp256k1_scalar *q);
+/**
+ * Multiply: R = q*A (in constant-time)
+ * Here `bits` should be set to the maximum bitlength of the _absolute value_ of `q`, plus
+ * one because we internally sometimes add 2 to the number during the WNAF conversion.
+ */
+static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, const secp256k1_scalar *q, int bits);
 
-#endif
+#endif /* SECP256K1_ECMULT_CONST_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecmult_const_impl.h b/crypto/secp256k1/libsecp256k1/src/ecmult_const_impl.h
index 0db314c48..011ccf0d4 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecmult_const_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecmult_const_impl.h
@@ -4,26 +4,21 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECMULT_CONST_IMPL_
-#define _SECP256K1_ECMULT_CONST_IMPL_
+#ifndef SECP256K1_ECMULT_CONST_IMPL_H
+#define SECP256K1_ECMULT_CONST_IMPL_H
 
 #include "scalar.h"
 #include "group.h"
 #include "ecmult_const.h"
 #include "ecmult_impl.h"
 
-#ifdef USE_ENDOMORPHISM
-    #define WNAF_BITS 128
-#else
-    #define WNAF_BITS 256
-#endif
-#define WNAF_SIZE(w) ((WNAF_BITS + (w) - 1) / (w))
-
 /* This is like `ECMULT_TABLE_GET_GE` but is constant time */
 #define ECMULT_CONST_TABLE_GET_GE(r,pre,n,w) do { \
     int m; \
-    int abs_n = (n) * (((n) > 0) * 2 - 1); \
-    int idx_n = abs_n / 2; \
+    /* Extract the sign-bit for a constant time absolute-value. */ \
+    int mask = (n) >> (sizeof(n) * CHAR_BIT - 1); \
+    int abs_n = ((n) + mask) ^ mask; \
+    int idx_n = abs_n >> 1; \
     secp256k1_fe neg_y; \
     VERIFY_CHECK(((n) & 1) == 1); \
     VERIFY_CHECK((n) >= -((1 << ((w)-1)) - 1)); \
@@ -42,19 +37,20 @@
 } while(0)
 
 
-/** Convert a number to WNAF notation. The number becomes represented by sum(2^{wi} * wnaf[i], i=0..return_val)
- *  with the following guarantees:
+/** Convert a number to WNAF notation.
+ *  The number becomes represented by sum(2^{wi} * wnaf[i], i=0..WNAF_SIZE(w)+1) - return_val.
+ *  It has the following guarantees:
  *  - each wnaf[i] an odd integer between -(1 << w) and (1 << w)
  *  - each wnaf[i] is nonzero
- *  - the number of words set is returned; this is always (WNAF_BITS + w - 1) / w
+ *  - the number of words set is always WNAF_SIZE(w) + 1
  *
  *  Adapted from `The Width-w NAF Method Provides Small Memory and Fast Elliptic Scalar
  *  Multiplications Secure against Side Channel Attacks`, Okeya and Tagaki. M. Joye (Ed.)
- *  CT-RSA 2003, LNCS 2612, pp. 328-443, 2003. Springer-Verlagy Berlin Heidelberg 2003
+ *  CT-RSA 2003, LNCS 2612, pp. 328-443, 2003. Springer-Verlag Berlin Heidelberg 2003
  *
  *  Numbers reference steps of `Algorithm SPA-resistant Width-w NAF with Odd Scalar` on pp. 335
  */
-static int secp256k1_wnaf_const(int *wnaf, secp256k1_scalar s, int w) {
+static int secp256k1_wnaf_const(int *wnaf, const secp256k1_scalar *scalar, int w, int size) {
     int global_sign;
     int skew = 0;
     int word = 0;
@@ -65,23 +61,33 @@ static int secp256k1_wnaf_const(int *wnaf, secp256k1_scalar s, int w) {
 
     int flip;
     int bit;
-    secp256k1_scalar neg_s;
+    secp256k1_scalar s;
     int not_neg_one;
+
+    VERIFY_CHECK(w > 0);
+    VERIFY_CHECK(size > 0);
+
     /* Note that we cannot handle even numbers by negating them to be odd, as is
      * done in other implementations, since if our scalars were specified to have
      * width < 256 for performance reasons, their negations would have width 256
      * and we'd lose any performance benefit. Instead, we use a technique from
      * Section 4.2 of the Okeya/Tagaki paper, which is to add either 1 (for even)
      * or 2 (for odd) to the number we are encoding, returning a skew value indicating
-     * this, and having the caller compensate after doing the multiplication. */
-
-    /* Negative numbers will be negated to keep their bit representation below the maximum width */
-    flip = secp256k1_scalar_is_high(&s);
+     * this, and having the caller compensate after doing the multiplication.
+     *
+     * In fact, we _do_ want to negate numbers to minimize their bit-lengths (and in
+     * particular, to ensure that the outputs from the endomorphism-split fit into
+     * 128 bits). If we negate, the parity of our number flips, inverting which of
+     * {1, 2} we want to add to the scalar when ensuring that it's odd. Further
+     * complicating things, -1 interacts badly with `secp256k1_scalar_cadd_bit` and
+     * we need to special-case it in this logic. */
+    flip = secp256k1_scalar_is_high(scalar);
     /* We add 1 to even numbers, 2 to odd ones, noting that negation flips parity */
-    bit = flip ^ !secp256k1_scalar_is_even(&s);
+    bit = flip ^ !secp256k1_scalar_is_even(scalar);
     /* We check for negative one, since adding 2 to it will cause an overflow */
-    secp256k1_scalar_negate(&neg_s, &s);
-    not_neg_one = !secp256k1_scalar_is_one(&neg_s);
+    secp256k1_scalar_negate(&s, scalar);
+    not_neg_one = !secp256k1_scalar_is_one(&s);
+    s = *scalar;
     secp256k1_scalar_cadd_bit(&s, bit, not_neg_one);
     /* If we had negative one, flip == 1, s.d[0] == 0, bit == 1, so caller expects
      * that we added two to it and flipped it. In fact for -1 these operations are
@@ -94,7 +100,7 @@ static int secp256k1_wnaf_const(int *wnaf, secp256k1_scalar s, int w) {
 
     /* 4 */
     u_last = secp256k1_scalar_shr_int(&s, w);
-    while (word * w < WNAF_BITS) {
+    do {
         int sign;
         int even;
 
@@ -110,41 +116,47 @@ static int secp256k1_wnaf_const(int *wnaf, secp256k1_scalar s, int w) {
         wnaf[word++] = u_last * global_sign;
 
         u_last = u;
-    }
+    } while (word * w < size);
     wnaf[word] = u * global_sign;
 
     VERIFY_CHECK(secp256k1_scalar_is_zero(&s));
-    VERIFY_CHECK(word == WNAF_SIZE(w));
+    VERIFY_CHECK(word == WNAF_SIZE_BITS(size, w));
     return skew;
 }
 
-
-static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, const secp256k1_scalar *scalar) {
+static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, const secp256k1_scalar *scalar, int size) {
     secp256k1_ge pre_a[ECMULT_TABLE_SIZE(WINDOW_A)];
     secp256k1_ge tmpa;
     secp256k1_fe Z;
 
     int skew_1;
-    int wnaf_1[1 + WNAF_SIZE(WINDOW_A - 1)];
 #ifdef USE_ENDOMORPHISM
     secp256k1_ge pre_a_lam[ECMULT_TABLE_SIZE(WINDOW_A)];
     int wnaf_lam[1 + WNAF_SIZE(WINDOW_A - 1)];
     int skew_lam;
     secp256k1_scalar q_1, q_lam;
 #endif
+    int wnaf_1[1 + WNAF_SIZE(WINDOW_A - 1)];
 
     int i;
-    secp256k1_scalar sc = *scalar;
 
     /* build wnaf representation for q. */
+    int rsize = size;
 #ifdef USE_ENDOMORPHISM
-    /* split q into q_1 and q_lam (where q = q_1 + q_lam*lambda, and q_1 and q_lam are ~128 bit) */
-    secp256k1_scalar_split_lambda(&q_1, &q_lam, &sc);
-    skew_1   = secp256k1_wnaf_const(wnaf_1,   q_1,   WINDOW_A - 1);
-    skew_lam = secp256k1_wnaf_const(wnaf_lam, q_lam, WINDOW_A - 1);
-#else
-    skew_1   = secp256k1_wnaf_const(wnaf_1, sc, WINDOW_A - 1);
+    if (size > 128) {
+        rsize = 128;
+        /* split q into q_1 and q_lam (where q = q_1 + q_lam*lambda, and q_1 and q_lam are ~128 bit) */
+        secp256k1_scalar_split_lambda(&q_1, &q_lam, scalar);
+        skew_1   = secp256k1_wnaf_const(wnaf_1,   &q_1,   WINDOW_A - 1, 128);
+        skew_lam = secp256k1_wnaf_const(wnaf_lam, &q_lam, WINDOW_A - 1, 128);
+    } else
 #endif
+    {
+        skew_1   = secp256k1_wnaf_const(wnaf_1, scalar, WINDOW_A - 1, size);
+#ifdef USE_ENDOMORPHISM
+        skew_lam = 0;
+#endif
+    }
 
     /* Calculate odd multiples of a.
      * All multiples are brought to the same Z 'denominator', which is stored
@@ -158,30 +170,35 @@ static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, cons
         secp256k1_fe_normalize_weak(&pre_a[i].y);
     }
 #ifdef USE_ENDOMORPHISM
-    for (i = 0; i < ECMULT_TABLE_SIZE(WINDOW_A); i++) {
-        secp256k1_ge_mul_lambda(&pre_a_lam[i], &pre_a[i]);
+    if (size > 128) {
+        for (i = 0; i < ECMULT_TABLE_SIZE(WINDOW_A); i++) {
+            secp256k1_ge_mul_lambda(&pre_a_lam[i], &pre_a[i]);
+        }
+
     }
 #endif
 
     /* first loop iteration (separated out so we can directly set r, rather
      * than having it start at infinity, get doubled several times, then have
      * its new value added to it) */
-    i = wnaf_1[WNAF_SIZE(WINDOW_A - 1)];
+    i = wnaf_1[WNAF_SIZE_BITS(rsize, WINDOW_A - 1)];
     VERIFY_CHECK(i != 0);
     ECMULT_CONST_TABLE_GET_GE(&tmpa, pre_a, i, WINDOW_A);
     secp256k1_gej_set_ge(r, &tmpa);
 #ifdef USE_ENDOMORPHISM
-    i = wnaf_lam[WNAF_SIZE(WINDOW_A - 1)];
-    VERIFY_CHECK(i != 0);
-    ECMULT_CONST_TABLE_GET_GE(&tmpa, pre_a_lam, i, WINDOW_A);
-    secp256k1_gej_add_ge(r, r, &tmpa);
+    if (size > 128) {
+        i = wnaf_lam[WNAF_SIZE_BITS(rsize, WINDOW_A - 1)];
+        VERIFY_CHECK(i != 0);
+        ECMULT_CONST_TABLE_GET_GE(&tmpa, pre_a_lam, i, WINDOW_A);
+        secp256k1_gej_add_ge(r, r, &tmpa);
+    }
 #endif
     /* remaining loop iterations */
-    for (i = WNAF_SIZE(WINDOW_A - 1) - 1; i >= 0; i--) {
+    for (i = WNAF_SIZE_BITS(rsize, WINDOW_A - 1) - 1; i >= 0; i--) {
         int n;
         int j;
         for (j = 0; j < WINDOW_A - 1; ++j) {
-            secp256k1_gej_double_nonzero(r, r, NULL);
+            secp256k1_gej_double_nonzero(r, r);
         }
 
         n = wnaf_1[i];
@@ -189,10 +206,12 @@ static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, cons
         VERIFY_CHECK(n != 0);
         secp256k1_gej_add_ge(r, r, &tmpa);
 #ifdef USE_ENDOMORPHISM
-        n = wnaf_lam[i];
-        ECMULT_CONST_TABLE_GET_GE(&tmpa, pre_a_lam, n, WINDOW_A);
-        VERIFY_CHECK(n != 0);
-        secp256k1_gej_add_ge(r, r, &tmpa);
+        if (size > 128) {
+            n = wnaf_lam[i];
+            ECMULT_CONST_TABLE_GET_GE(&tmpa, pre_a_lam, n, WINDOW_A);
+            VERIFY_CHECK(n != 0);
+            secp256k1_gej_add_ge(r, r, &tmpa);
+        }
 #endif
     }
 
@@ -212,14 +231,18 @@ static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, cons
         secp256k1_ge_set_gej(&correction, &tmpj);
         secp256k1_ge_to_storage(&correction_1_stor, a);
 #ifdef USE_ENDOMORPHISM
-        secp256k1_ge_to_storage(&correction_lam_stor, a);
+        if (size > 128) {
+            secp256k1_ge_to_storage(&correction_lam_stor, a);
+        }
 #endif
         secp256k1_ge_to_storage(&a2_stor, &correction);
 
         /* For odd numbers this is 2a (so replace it), for even ones a (so no-op) */
         secp256k1_ge_storage_cmov(&correction_1_stor, &a2_stor, skew_1 == 2);
 #ifdef USE_ENDOMORPHISM
-        secp256k1_ge_storage_cmov(&correction_lam_stor, &a2_stor, skew_lam == 2);
+        if (size > 128) {
+            secp256k1_ge_storage_cmov(&correction_lam_stor, &a2_stor, skew_lam == 2);
+        }
 #endif
 
         /* Apply the correction */
@@ -228,12 +251,14 @@ static void secp256k1_ecmult_const(secp256k1_gej *r, const secp256k1_ge *a, cons
         secp256k1_gej_add_ge(r, r, &correction);
 
 #ifdef USE_ENDOMORPHISM
-        secp256k1_ge_from_storage(&correction, &correction_lam_stor);
-        secp256k1_ge_neg(&correction, &correction);
-        secp256k1_ge_mul_lambda(&correction, &correction);
-        secp256k1_gej_add_ge(r, r, &correction);
+        if (size > 128) {
+            secp256k1_ge_from_storage(&correction, &correction_lam_stor);
+            secp256k1_ge_neg(&correction, &correction);
+            secp256k1_ge_mul_lambda(&correction, &correction);
+            secp256k1_gej_add_ge(r, r, &correction);
+        }
 #endif
     }
 }
 
-#endif
+#endif /* SECP256K1_ECMULT_CONST_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecmult_gen.h b/crypto/secp256k1/libsecp256k1/src/ecmult_gen.h
index eb2cc9ead..30815e5aa 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecmult_gen.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecmult_gen.h
@@ -4,34 +4,41 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECMULT_GEN_
-#define _SECP256K1_ECMULT_GEN_
+#ifndef SECP256K1_ECMULT_GEN_H
+#define SECP256K1_ECMULT_GEN_H
 
 #include "scalar.h"
 #include "group.h"
 
+#if ECMULT_GEN_PREC_BITS != 2 && ECMULT_GEN_PREC_BITS != 4 && ECMULT_GEN_PREC_BITS != 8
+#  error "Set ECMULT_GEN_PREC_BITS to 2, 4 or 8."
+#endif
+#define ECMULT_GEN_PREC_B ECMULT_GEN_PREC_BITS
+#define ECMULT_GEN_PREC_G (1 << ECMULT_GEN_PREC_B)
+#define ECMULT_GEN_PREC_N (256 / ECMULT_GEN_PREC_B)
+
 typedef struct {
     /* For accelerating the computation of a*G:
      * To harden against timing attacks, use the following mechanism:
-     * * Break up the multiplicand into groups of 4 bits, called n_0, n_1, n_2, ..., n_63.
-     * * Compute sum(n_i * 16^i * G + U_i, i=0..63), where:
-     *   * U_i = U * 2^i (for i=0..62)
-     *   * U_i = U * (1-2^63) (for i=63)
-     *   where U is a point with no known corresponding scalar. Note that sum(U_i, i=0..63) = 0.
-     * For each i, and each of the 16 possible values of n_i, (n_i * 16^i * G + U_i) is
-     * precomputed (call it prec(i, n_i)). The formula now becomes sum(prec(i, n_i), i=0..63).
+     * * Break up the multiplicand into groups of PREC_B bits, called n_0, n_1, n_2, ..., n_(PREC_N-1).
+     * * Compute sum(n_i * (PREC_G)^i * G + U_i, i=0 ... PREC_N-1), where:
+     *   * U_i = U * 2^i, for i=0 ... PREC_N-2
+     *   * U_i = U * (1-2^(PREC_N-1)), for i=PREC_N-1
+     *   where U is a point with no known corresponding scalar. Note that sum(U_i, i=0 ... PREC_N-1) = 0.
+     * For each i, and each of the PREC_G possible values of n_i, (n_i * (PREC_G)^i * G + U_i) is
+     * precomputed (call it prec(i, n_i)). The formula now becomes sum(prec(i, n_i), i=0 ... PREC_N-1).
      * None of the resulting prec group elements have a known scalar, and neither do any of
      * the intermediate sums while computing a*G.
      */
-    secp256k1_ge_storage (*prec)[64][16]; /* prec[j][i] = 16^j * i * G + U_i */
+    secp256k1_ge_storage (*prec)[ECMULT_GEN_PREC_N][ECMULT_GEN_PREC_G]; /* prec[j][i] = (PREC_G)^j * i * G + U_i */
     secp256k1_scalar blind;
     secp256k1_gej initial;
 } secp256k1_ecmult_gen_context;
 
+static const size_t SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE;
 static void secp256k1_ecmult_gen_context_init(secp256k1_ecmult_gen_context* ctx);
-static void secp256k1_ecmult_gen_context_build(secp256k1_ecmult_gen_context* ctx, const secp256k1_callback* cb);
-static void secp256k1_ecmult_gen_context_clone(secp256k1_ecmult_gen_context *dst,
-                                               const secp256k1_ecmult_gen_context* src, const secp256k1_callback* cb);
+static void secp256k1_ecmult_gen_context_build(secp256k1_ecmult_gen_context* ctx, void **prealloc);
+static void secp256k1_ecmult_gen_context_finalize_memcpy(secp256k1_ecmult_gen_context *dst, const secp256k1_ecmult_gen_context* src);
 static void secp256k1_ecmult_gen_context_clear(secp256k1_ecmult_gen_context* ctx);
 static int secp256k1_ecmult_gen_context_is_built(const secp256k1_ecmult_gen_context* ctx);
 
@@ -40,4 +47,4 @@ static void secp256k1_ecmult_gen(const secp256k1_ecmult_gen_context* ctx, secp25
 
 static void secp256k1_ecmult_gen_blind(secp256k1_ecmult_gen_context *ctx, const unsigned char *seed32);
 
-#endif
+#endif /* SECP256K1_ECMULT_GEN_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecmult_gen_impl.h b/crypto/secp256k1/libsecp256k1/src/ecmult_gen_impl.h
index 35f254607..30ac16518 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecmult_gen_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecmult_gen_impl.h
@@ -4,9 +4,10 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_ECMULT_GEN_IMPL_H_
-#define _SECP256K1_ECMULT_GEN_IMPL_H_
+#ifndef SECP256K1_ECMULT_GEN_IMPL_H
+#define SECP256K1_ECMULT_GEN_IMPL_H
 
+#include "util.h"
 #include "scalar.h"
 #include "group.h"
 #include "ecmult_gen.h"
@@ -14,23 +15,32 @@
 #ifdef USE_ECMULT_STATIC_PRECOMPUTATION
 #include "ecmult_static_context.h"
 #endif
+
+#ifndef USE_ECMULT_STATIC_PRECOMPUTATION
+    static const size_t SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE = ROUND_TO_ALIGN(sizeof(*((secp256k1_ecmult_gen_context*) NULL)->prec));
+#else
+    static const size_t SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE = 0;
+#endif
+
 static void secp256k1_ecmult_gen_context_init(secp256k1_ecmult_gen_context *ctx) {
     ctx->prec = NULL;
 }
 
-static void secp256k1_ecmult_gen_context_build(secp256k1_ecmult_gen_context *ctx, const secp256k1_callback* cb) {
+static void secp256k1_ecmult_gen_context_build(secp256k1_ecmult_gen_context *ctx, void **prealloc) {
 #ifndef USE_ECMULT_STATIC_PRECOMPUTATION
-    secp256k1_ge prec[1024];
+    secp256k1_ge prec[ECMULT_GEN_PREC_N * ECMULT_GEN_PREC_G];
     secp256k1_gej gj;
     secp256k1_gej nums_gej;
     int i, j;
+    size_t const prealloc_size = SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE;
+    void* const base = *prealloc;
 #endif
 
     if (ctx->prec != NULL) {
         return;
     }
 #ifndef USE_ECMULT_STATIC_PRECOMPUTATION
-    ctx->prec = (secp256k1_ge_storage (*)[64][16])checked_malloc(cb, sizeof(*ctx->prec));
+    ctx->prec = (secp256k1_ge_storage (*)[ECMULT_GEN_PREC_N][ECMULT_GEN_PREC_G])manual_alloc(prealloc, prealloc_size, base, prealloc_size);
 
     /* get the generator */
     secp256k1_gej_set_ge(&gj, &secp256k1_ge_const_g);
@@ -54,39 +64,39 @@ static void secp256k1_ecmult_gen_context_build(secp256k1_ecmult_gen_context *ctx
 
     /* compute prec. */
     {
-        secp256k1_gej precj[1024]; /* Jacobian versions of prec. */
+        secp256k1_gej precj[ECMULT_GEN_PREC_N * ECMULT_GEN_PREC_G]; /* Jacobian versions of prec. */
         secp256k1_gej gbase;
         secp256k1_gej numsbase;
-        gbase = gj; /* 16^j * G */
+        gbase = gj; /* PREC_G^j * G */
         numsbase = nums_gej; /* 2^j * nums. */
-        for (j = 0; j < 64; j++) {
-            /* Set precj[j*16 .. j*16+15] to (numsbase, numsbase + gbase, ..., numsbase + 15*gbase). */
-            precj[j*16] = numsbase;
-            for (i = 1; i < 16; i++) {
-                secp256k1_gej_add_var(&precj[j*16 + i], &precj[j*16 + i - 1], &gbase, NULL);
+        for (j = 0; j < ECMULT_GEN_PREC_N; j++) {
+            /* Set precj[j*PREC_G .. j*PREC_G+(PREC_G-1)] to (numsbase, numsbase + gbase, ..., numsbase + (PREC_G-1)*gbase). */
+            precj[j*ECMULT_GEN_PREC_G] = numsbase;
+            for (i = 1; i < ECMULT_GEN_PREC_G; i++) {
+                secp256k1_gej_add_var(&precj[j*ECMULT_GEN_PREC_G + i], &precj[j*ECMULT_GEN_PREC_G + i - 1], &gbase, NULL);
             }
-            /* Multiply gbase by 16. */
-            for (i = 0; i < 4; i++) {
+            /* Multiply gbase by PREC_G. */
+            for (i = 0; i < ECMULT_GEN_PREC_B; i++) {
                 secp256k1_gej_double_var(&gbase, &gbase, NULL);
             }
             /* Multiply numbase by 2. */
             secp256k1_gej_double_var(&numsbase, &numsbase, NULL);
-            if (j == 62) {
+            if (j == ECMULT_GEN_PREC_N - 2) {
                 /* In the last iteration, numsbase is (1 - 2^j) * nums instead. */
                 secp256k1_gej_neg(&numsbase, &numsbase);
                 secp256k1_gej_add_var(&numsbase, &numsbase, &nums_gej, NULL);
             }
         }
-        secp256k1_ge_set_all_gej_var(prec, precj, 1024, cb);
+        secp256k1_ge_set_all_gej_var(prec, precj, ECMULT_GEN_PREC_N * ECMULT_GEN_PREC_G);
     }
-    for (j = 0; j < 64; j++) {
-        for (i = 0; i < 16; i++) {
-            secp256k1_ge_to_storage(&(*ctx->prec)[j][i], &prec[j*16 + i]);
+    for (j = 0; j < ECMULT_GEN_PREC_N; j++) {
+        for (i = 0; i < ECMULT_GEN_PREC_G; i++) {
+            secp256k1_ge_to_storage(&(*ctx->prec)[j][i], &prec[j*ECMULT_GEN_PREC_G + i]);
         }
     }
 #else
-    (void)cb;
-    ctx->prec = (secp256k1_ge_storage (*)[64][16])secp256k1_ecmult_static_context;
+    (void)prealloc;
+    ctx->prec = (secp256k1_ge_storage (*)[ECMULT_GEN_PREC_N][ECMULT_GEN_PREC_G])secp256k1_ecmult_static_context;
 #endif
     secp256k1_ecmult_gen_blind(ctx, NULL);
 }
@@ -95,27 +105,18 @@ static int secp256k1_ecmult_gen_context_is_built(const secp256k1_ecmult_gen_cont
     return ctx->prec != NULL;
 }
 
-static void secp256k1_ecmult_gen_context_clone(secp256k1_ecmult_gen_context *dst,
-                                               const secp256k1_ecmult_gen_context *src, const secp256k1_callback* cb) {
-    if (src->prec == NULL) {
-        dst->prec = NULL;
-    } else {
+static void secp256k1_ecmult_gen_context_finalize_memcpy(secp256k1_ecmult_gen_context *dst, const secp256k1_ecmult_gen_context *src) {
 #ifndef USE_ECMULT_STATIC_PRECOMPUTATION
-        dst->prec = (secp256k1_ge_storage (*)[64][16])checked_malloc(cb, sizeof(*dst->prec));
-        memcpy(dst->prec, src->prec, sizeof(*dst->prec));
+    if (src->prec != NULL) {
+        /* We cast to void* first to suppress a -Wcast-align warning. */
+        dst->prec = (secp256k1_ge_storage (*)[ECMULT_GEN_PREC_N][ECMULT_GEN_PREC_G])(void*)((unsigned char*)dst + ((unsigned char*)src->prec - (unsigned char*)src));
+    }
 #else
-        (void)cb;
-        dst->prec = src->prec;
+    (void)dst, (void)src;
 #endif
-        dst->initial = src->initial;
-        dst->blind = src->blind;
-    }
 }
 
 static void secp256k1_ecmult_gen_context_clear(secp256k1_ecmult_gen_context *ctx) {
-#ifndef USE_ECMULT_STATIC_PRECOMPUTATION
-    free(ctx->prec);
-#endif
     secp256k1_scalar_clear(&ctx->blind);
     secp256k1_gej_clear(&ctx->initial);
     ctx->prec = NULL;
@@ -132,9 +133,9 @@ static void secp256k1_ecmult_gen(const secp256k1_ecmult_gen_context *ctx, secp25
     /* Blind scalar/point multiplication by computing (n-b)G + bG instead of nG. */
     secp256k1_scalar_add(&gnb, gn, &ctx->blind);
     add.infinity = 0;
-    for (j = 0; j < 64; j++) {
-        bits = secp256k1_scalar_get_bits(&gnb, j * 4, 4);
-        for (i = 0; i < 16; i++) {
+    for (j = 0; j < ECMULT_GEN_PREC_N; j++) {
+        bits = secp256k1_scalar_get_bits(&gnb, j * ECMULT_GEN_PREC_B, ECMULT_GEN_PREC_B);
+        for (i = 0; i < ECMULT_GEN_PREC_G; i++) {
             /** This uses a conditional move to avoid any secret data in array indexes.
              *   _Any_ use of secret indexes has been demonstrated to result in timing
              *   sidechannels, even when the cache-line access patterns are uniform.
@@ -161,8 +162,8 @@ static void secp256k1_ecmult_gen_blind(secp256k1_ecmult_gen_context *ctx, const
     secp256k1_gej gb;
     secp256k1_fe s;
     unsigned char nonce32[32];
-    secp256k1_rfc6979_hmac_sha256_t rng;
-    int retry;
+    secp256k1_rfc6979_hmac_sha256 rng;
+    int overflow;
     unsigned char keydata[64] = {0};
     if (seed32 == NULL) {
         /* When seed is NULL, reset the initial point and blinding value. */
@@ -182,21 +183,18 @@ static void secp256k1_ecmult_gen_blind(secp256k1_ecmult_gen_context *ctx, const
     }
     secp256k1_rfc6979_hmac_sha256_initialize(&rng, keydata, seed32 ? 64 : 32);
     memset(keydata, 0, sizeof(keydata));
-    /* Retry for out of range results to achieve uniformity. */
-    do {
-        secp256k1_rfc6979_hmac_sha256_generate(&rng, nonce32, 32);
-        retry = !secp256k1_fe_set_b32(&s, nonce32);
-        retry |= secp256k1_fe_is_zero(&s);
-    } while (retry); /* This branch true is cryptographically unreachable. Requires sha256_hmac output > Fp. */
+    /* Accept unobservably small non-uniformity. */
+    secp256k1_rfc6979_hmac_sha256_generate(&rng, nonce32, 32);
+    overflow = !secp256k1_fe_set_b32(&s, nonce32);
+    overflow |= secp256k1_fe_is_zero(&s);
+    secp256k1_fe_cmov(&s, &secp256k1_fe_one, overflow);
     /* Randomize the projection to defend against multiplier sidechannels. */
     secp256k1_gej_rescale(&ctx->initial, &s);
     secp256k1_fe_clear(&s);
-    do {
-        secp256k1_rfc6979_hmac_sha256_generate(&rng, nonce32, 32);
-        secp256k1_scalar_set_b32(&b, nonce32, &retry);
-        /* A blinding value of 0 works, but would undermine the projection hardening. */
-        retry |= secp256k1_scalar_is_zero(&b);
-    } while (retry); /* This branch true is cryptographically unreachable. Requires sha256_hmac output > order. */
+    secp256k1_rfc6979_hmac_sha256_generate(&rng, nonce32, 32);
+    secp256k1_scalar_set_b32(&b, nonce32, NULL);
+    /* A blinding value of 0 works, but would undermine the projection hardening. */
+    secp256k1_scalar_cmov(&b, &secp256k1_scalar_one, secp256k1_scalar_is_zero(&b));
     secp256k1_rfc6979_hmac_sha256_finalize(&rng);
     memset(nonce32, 0, 32);
     secp256k1_ecmult_gen(ctx, &gb, &b);
@@ -207,4 +205,4 @@ static void secp256k1_ecmult_gen_blind(secp256k1_ecmult_gen_context *ctx, const
     secp256k1_gej_clear(&gb);
 }
 
-#endif
+#endif /* SECP256K1_ECMULT_GEN_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/ecmult_impl.h b/crypto/secp256k1/libsecp256k1/src/ecmult_impl.h
index 4e40104ad..f03fa9469 100644
--- a/crypto/secp256k1/libsecp256k1/src/ecmult_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/ecmult_impl.h
@@ -1,14 +1,16 @@
-/**********************************************************************
- * Copyright (c) 2013, 2014 Pieter Wuille                             *
- * Distributed under the MIT software license, see the accompanying   *
- * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
- **********************************************************************/
+/*****************************************************************************
+ * Copyright (c) 2013, 2014, 2017 Pieter Wuille, Andrew Poelstra, Jonas Nick *
+ * Distributed under the MIT software license, see the accompanying          *
+ * file COPYING or http://www.opensource.org/licenses/mit-license.php.       *
+ *****************************************************************************/
 
-#ifndef _SECP256K1_ECMULT_IMPL_H_
-#define _SECP256K1_ECMULT_IMPL_H_
+#ifndef SECP256K1_ECMULT_IMPL_H
+#define SECP256K1_ECMULT_IMPL_H
 
 #include <string.h>
+#include <stdint.h>
 
+#include "util.h"
 #include "group.h"
 #include "scalar.h"
 #include "ecmult.h"
@@ -29,21 +31,64 @@
 #  endif
 #else
 /* optimal for 128-bit and 256-bit exponents. */
-#define WINDOW_A 5
-/** larger numbers may result in slightly better performance, at the cost of
-    exponentially larger precomputed tables. */
+#  define WINDOW_A 5
+/** Larger values for ECMULT_WINDOW_SIZE result in possibly better
+ *  performance at the cost of an exponentially larger precomputed
+ *  table. The exact table size is
+ *      (1 << (WINDOW_G - 2)) * sizeof(secp256k1_ge_storage)  bytes,
+ *  where sizeof(secp256k1_ge_storage) is typically 64 bytes but can
+ *  be larger due to platform-specific padding and alignment.
+ *  If the endomorphism optimization is enabled (USE_ENDOMORMPHSIM)
+ *  two tables of this size are used instead of only one.
+ */
+#  define WINDOW_G ECMULT_WINDOW_SIZE
+#endif
+
+/* Noone will ever need more than a window size of 24. The code might
+ * be correct for larger values of ECMULT_WINDOW_SIZE but this is not
+ * not tested.
+ *
+ * The following limitations are known, and there are probably more:
+ * If WINDOW_G > 27 and size_t has 32 bits, then the code is incorrect
+ * because the size of the memory object that we allocate (in bytes)
+ * will not fit in a size_t.
+ * If WINDOW_G > 31 and int has 32 bits, then the code is incorrect
+ * because certain expressions will overflow.
+ */
+#if ECMULT_WINDOW_SIZE < 2 || ECMULT_WINDOW_SIZE > 24
+#  error Set ECMULT_WINDOW_SIZE to an integer in range [2..24].
+#endif
+
 #ifdef USE_ENDOMORPHISM
-/** Two tables for window size 15: 1.375 MiB. */
-#define WINDOW_G 15
+    #define WNAF_BITS 128
 #else
-/** One table for window size 16: 1.375 MiB. */
-#define WINDOW_G 16
-#endif
+    #define WNAF_BITS 256
 #endif
+#define WNAF_SIZE_BITS(bits, w) (((bits) + (w) - 1) / (w))
+#define WNAF_SIZE(w) WNAF_SIZE_BITS(WNAF_BITS, w)
 
 /** The number of entries a table with precomputed multiples needs to have. */
 #define ECMULT_TABLE_SIZE(w) (1 << ((w)-2))
 
+/* The number of objects allocated on the scratch space for ecmult_multi algorithms */
+#define PIPPENGER_SCRATCH_OBJECTS 6
+#define STRAUSS_SCRATCH_OBJECTS 6
+
+#define PIPPENGER_MAX_BUCKET_WINDOW 12
+
+/* Minimum number of points for which pippenger_wnaf is faster than strauss wnaf */
+#ifdef USE_ENDOMORPHISM
+    #define ECMULT_PIPPENGER_THRESHOLD 88
+#else
+    #define ECMULT_PIPPENGER_THRESHOLD 160
+#endif
+
+#ifdef USE_ENDOMORPHISM
+    #define ECMULT_MAX_POINTS_PER_BATCH 5000000
+#else
+    #define ECMULT_MAX_POINTS_PER_BATCH 10000000
+#endif
+
 /** Fill a table 'prej' with precomputed odd multiples of a. Prej will contain
  *  the values [1*a,3*a,...,(2*n-1)*a], so it space for n values. zr[0] will
  *  contain prej[0].z / a.z. The other zr[i] values = prej[i].z / prej[i-1].z.
@@ -93,7 +138,7 @@ static void secp256k1_ecmult_odd_multiples_table(int n, secp256k1_gej *prej, sec
  *    It only operates on tables sized for WINDOW_A wnaf multiples.
  *  - secp256k1_ecmult_odd_multiples_table_storage_var, which converts its
  *    resulting point set to actually affine points, and stores those in pre.
- *    It operates on tables of any size, but uses heap-allocated temporaries.
+ *    It operates on tables of any size.
  *
  *  To compute a*P + b*G, we compute a table for P using the first function,
  *  and for G using the second (which requires an inverse, but it only needs to
@@ -109,24 +154,135 @@ static void secp256k1_ecmult_odd_multiples_table_globalz_windowa(secp256k1_ge *p
     secp256k1_ge_globalz_set_table_gej(ECMULT_TABLE_SIZE(WINDOW_A), pre, globalz, prej, zr);
 }
 
-static void secp256k1_ecmult_odd_multiples_table_storage_var(int n, secp256k1_ge_storage *pre, const secp256k1_gej *a, const secp256k1_callback *cb) {
-    secp256k1_gej *prej = (secp256k1_gej*)checked_malloc(cb, sizeof(secp256k1_gej) * n);
-    secp256k1_ge *prea = (secp256k1_ge*)checked_malloc(cb, sizeof(secp256k1_ge) * n);
-    secp256k1_fe *zr = (secp256k1_fe*)checked_malloc(cb, sizeof(secp256k1_fe) * n);
+static void secp256k1_ecmult_odd_multiples_table_storage_var(const int n, secp256k1_ge_storage *pre, const secp256k1_gej *a) {
+    secp256k1_gej d;
+    secp256k1_ge d_ge, p_ge;
+    secp256k1_gej pj;
+    secp256k1_fe zi;
+    secp256k1_fe zr;
+    secp256k1_fe dx_over_dz_squared;
     int i;
 
-    /* Compute the odd multiples in Jacobian form. */
-    secp256k1_ecmult_odd_multiples_table(n, prej, zr, a);
-    /* Convert them in batch to affine coordinates. */
-    secp256k1_ge_set_table_gej_var(prea, prej, zr, n);
-    /* Convert them to compact storage form. */
-    for (i = 0; i < n; i++) {
-        secp256k1_ge_to_storage(&pre[i], &prea[i]);
+    VERIFY_CHECK(!a->infinity);
+
+    secp256k1_gej_double_var(&d, a, NULL);
+
+    /* First, we perform all the additions in an isomorphic curve obtained by multiplying
+     * all `z` coordinates by 1/`d.z`. In these coordinates `d` is affine so we can use
+     * `secp256k1_gej_add_ge_var` to perform the additions. For each addition, we store
+     * the resulting y-coordinate and the z-ratio, since we only have enough memory to
+     * store two field elements. These are sufficient to efficiently undo the isomorphism
+     * and recompute all the `x`s.
+     */
+    d_ge.x = d.x;
+    d_ge.y = d.y;
+    d_ge.infinity = 0;
+
+    secp256k1_ge_set_gej_zinv(&p_ge, a, &d.z);
+    pj.x = p_ge.x;
+    pj.y = p_ge.y;
+    pj.z = a->z;
+    pj.infinity = 0;
+
+    for (i = 0; i < (n - 1); i++) {
+        secp256k1_fe_normalize_var(&pj.y);
+        secp256k1_fe_to_storage(&pre[i].y, &pj.y);
+        secp256k1_gej_add_ge_var(&pj, &pj, &d_ge, &zr);
+        secp256k1_fe_normalize_var(&zr);
+        secp256k1_fe_to_storage(&pre[i].x, &zr);
     }
 
-    free(prea);
-    free(prej);
-    free(zr);
+    /* Invert d.z in the same batch, preserving pj.z so we can extract 1/d.z */
+    secp256k1_fe_mul(&zi, &pj.z, &d.z);
+    secp256k1_fe_inv_var(&zi, &zi);
+
+    /* Directly set `pre[n - 1]` to `pj`, saving the inverted z-coordinate so
+     * that we can combine it with the saved z-ratios to compute the other zs
+     * without any more inversions. */
+    secp256k1_ge_set_gej_zinv(&p_ge, &pj, &zi);
+    secp256k1_ge_to_storage(&pre[n - 1], &p_ge);
+
+    /* Compute the actual x-coordinate of D, which will be needed below. */
+    secp256k1_fe_mul(&d.z, &zi, &pj.z);  /* d.z = 1/d.z */
+    secp256k1_fe_sqr(&dx_over_dz_squared, &d.z);
+    secp256k1_fe_mul(&dx_over_dz_squared, &dx_over_dz_squared, &d.x);
+
+    /* Going into the second loop, we have set `pre[n-1]` to its final affine
+     * form, but still need to set `pre[i]` for `i` in 0 through `n-2`. We
+     * have `zi = (p.z * d.z)^-1`, where
+     *
+     *     `p.z` is the z-coordinate of the point on the isomorphic curve
+     *           which was ultimately assigned to `pre[n-1]`.
+     *     `d.z` is the multiplier that must be applied to all z-coordinates
+     *           to move from our isomorphic curve back to secp256k1; so the
+     *           product `p.z * d.z` is the z-coordinate of the secp256k1
+     *           point assigned to `pre[n-1]`.
+     *
+     * All subsequent inverse-z-coordinates can be obtained by multiplying this
+     * factor by successive z-ratios, which is much more efficient than directly
+     * computing each one.
+     *
+     * Importantly, these inverse-zs will be coordinates of points on secp256k1,
+     * while our other stored values come from computations on the isomorphic
+     * curve. So in the below loop, we will take care not to actually use `zi`
+     * or any derived values until we're back on secp256k1.
+     */
+    i = n - 1;
+    while (i > 0) {
+        secp256k1_fe zi2, zi3;
+        const secp256k1_fe *rzr;
+        i--;
+
+        secp256k1_ge_from_storage(&p_ge, &pre[i]);
+
+        /* For each remaining point, we extract the z-ratio from the stored
+         * x-coordinate, compute its z^-1 from that, and compute the full
+         * point from that. */
+        rzr = &p_ge.x;
+        secp256k1_fe_mul(&zi, &zi, rzr);
+        secp256k1_fe_sqr(&zi2, &zi);
+        secp256k1_fe_mul(&zi3, &zi2, &zi);
+        /* To compute the actual x-coordinate, we use the stored z ratio and
+         * y-coordinate, which we obtained from `secp256k1_gej_add_ge_var`
+         * in the loop above, as well as the inverse of the square of its
+         * z-coordinate. We store the latter in the `zi2` variable, which is
+         * computed iteratively starting from the overall Z inverse then
+         * multiplying by each z-ratio in turn.
+         *
+         * Denoting the z-ratio as `rzr`, we observe that it is equal to `h`
+         * from the inside of the above `gej_add_ge_var` call. This satisfies
+         *
+         *    rzr = d_x * z^2 - x * d_z^2
+         *
+         * where (`d_x`, `d_z`) are Jacobian coordinates of `D` and `(x, z)`
+         * are Jacobian coordinates of our desired point -- except both are on
+         * the isomorphic curve that we were using when we called `gej_add_ge_var`.
+         * To get back to secp256k1, we must multiply both `z`s by `d_z`, or
+         * equivalently divide both `x`s by `d_z^2`. Our equation then becomes
+         *
+         *    rzr = d_x * z^2 / d_z^2 - x
+         *
+         * (The left-hand-side, being a ratio of z-coordinates, is unaffected
+         * by the isomorphism.)
+         *
+         * Rearranging to solve for `x`, we have
+         *
+         *     x = d_x * z^2 / d_z^2 - rzr
+         *
+         * But what we actually want is the affine coordinate `X = x/z^2`,
+         * which will satisfy
+         *
+         *     X = d_x / d_z^2 - rzr / z^2
+         *       = dx_over_dz_squared - rzr * zi2
+         */
+        secp256k1_fe_mul(&p_ge.x, rzr, &zi2);
+        secp256k1_fe_negate(&p_ge.x, &p_ge.x, 1);
+        secp256k1_fe_add(&p_ge.x, &dx_over_dz_squared);
+        /* y is stored_y/z^3, as we expect */
+        secp256k1_fe_mul(&p_ge.y, &p_ge.y, &zi3);
+        /* Store */
+        secp256k1_ge_to_storage(&pre[i], &p_ge);
+    }
 }
 
 /** The following two macro retrieves a particular odd multiple from a table
@@ -138,7 +294,8 @@ static void secp256k1_ecmult_odd_multiples_table_storage_var(int n, secp256k1_ge
     if ((n) > 0) { \
         *(r) = (pre)[((n)-1)/2]; \
     } else { \
-        secp256k1_ge_neg((r), &(pre)[(-(n)-1)/2]); \
+        *(r) = (pre)[(-(n)-1)/2]; \
+        secp256k1_fe_negate(&((r)->y), &((r)->y), 1); \
     } \
 } while(0)
 
@@ -150,10 +307,17 @@ static void secp256k1_ecmult_odd_multiples_table_storage_var(int n, secp256k1_ge
         secp256k1_ge_from_storage((r), &(pre)[((n)-1)/2]); \
     } else { \
         secp256k1_ge_from_storage((r), &(pre)[(-(n)-1)/2]); \
-        secp256k1_ge_neg((r), (r)); \
+        secp256k1_fe_negate(&((r)->y), &((r)->y), 1); \
     } \
 } while(0)
 
+static const size_t SECP256K1_ECMULT_CONTEXT_PREALLOCATED_SIZE =
+    ROUND_TO_ALIGN(sizeof((*((secp256k1_ecmult_context*) NULL)->pre_g)[0]) * ECMULT_TABLE_SIZE(WINDOW_G))
+#ifdef USE_ENDOMORPHISM
+    + ROUND_TO_ALIGN(sizeof((*((secp256k1_ecmult_context*) NULL)->pre_g_128)[0]) * ECMULT_TABLE_SIZE(WINDOW_G))
+#endif
+    ;
+
 static void secp256k1_ecmult_context_init(secp256k1_ecmult_context *ctx) {
     ctx->pre_g = NULL;
 #ifdef USE_ENDOMORPHISM
@@ -161,8 +325,10 @@ static void secp256k1_ecmult_context_init(secp256k1_ecmult_context *ctx) {
 #endif
 }
 
-static void secp256k1_ecmult_context_build(secp256k1_ecmult_context *ctx, const secp256k1_callback *cb) {
+static void secp256k1_ecmult_context_build(secp256k1_ecmult_context *ctx, void **prealloc) {
     secp256k1_gej gj;
+    void* const base = *prealloc;
+    size_t const prealloc_size = SECP256K1_ECMULT_CONTEXT_PREALLOCATED_SIZE;
 
     if (ctx->pre_g != NULL) {
         return;
@@ -171,44 +337,44 @@ static void secp256k1_ecmult_context_build(secp256k1_ecmult_context *ctx, const
     /* get the generator */
     secp256k1_gej_set_ge(&gj, &secp256k1_ge_const_g);
 
-    ctx->pre_g = (secp256k1_ge_storage (*)[])checked_malloc(cb, sizeof((*ctx->pre_g)[0]) * ECMULT_TABLE_SIZE(WINDOW_G));
+    {
+        size_t size = sizeof((*ctx->pre_g)[0]) * ((size_t)ECMULT_TABLE_SIZE(WINDOW_G));
+        /* check for overflow */
+        VERIFY_CHECK(size / sizeof((*ctx->pre_g)[0]) == ((size_t)ECMULT_TABLE_SIZE(WINDOW_G)));
+        ctx->pre_g = (secp256k1_ge_storage (*)[])manual_alloc(prealloc, sizeof((*ctx->pre_g)[0]) * ECMULT_TABLE_SIZE(WINDOW_G), base, prealloc_size);
+    }
 
     /* precompute the tables with odd multiples */
-    secp256k1_ecmult_odd_multiples_table_storage_var(ECMULT_TABLE_SIZE(WINDOW_G), *ctx->pre_g, &gj, cb);
+    secp256k1_ecmult_odd_multiples_table_storage_var(ECMULT_TABLE_SIZE(WINDOW_G), *ctx->pre_g, &gj);
 
 #ifdef USE_ENDOMORPHISM
     {
         secp256k1_gej g_128j;
         int i;
 
-        ctx->pre_g_128 = (secp256k1_ge_storage (*)[])checked_malloc(cb, sizeof((*ctx->pre_g_128)[0]) * ECMULT_TABLE_SIZE(WINDOW_G));
+        size_t size = sizeof((*ctx->pre_g_128)[0]) * ((size_t) ECMULT_TABLE_SIZE(WINDOW_G));
+        /* check for overflow */
+        VERIFY_CHECK(size / sizeof((*ctx->pre_g_128)[0]) == ((size_t)ECMULT_TABLE_SIZE(WINDOW_G)));
+        ctx->pre_g_128 = (secp256k1_ge_storage (*)[])manual_alloc(prealloc, sizeof((*ctx->pre_g_128)[0]) * ECMULT_TABLE_SIZE(WINDOW_G), base, prealloc_size);
 
         /* calculate 2^128*generator */
         g_128j = gj;
         for (i = 0; i < 128; i++) {
             secp256k1_gej_double_var(&g_128j, &g_128j, NULL);
         }
-        secp256k1_ecmult_odd_multiples_table_storage_var(ECMULT_TABLE_SIZE(WINDOW_G), *ctx->pre_g_128, &g_128j, cb);
+        secp256k1_ecmult_odd_multiples_table_storage_var(ECMULT_TABLE_SIZE(WINDOW_G), *ctx->pre_g_128, &g_128j);
     }
 #endif
 }
 
-static void secp256k1_ecmult_context_clone(secp256k1_ecmult_context *dst,
-                                           const secp256k1_ecmult_context *src, const secp256k1_callback *cb) {
-    if (src->pre_g == NULL) {
-        dst->pre_g = NULL;
-    } else {
-        size_t size = sizeof((*dst->pre_g)[0]) * ECMULT_TABLE_SIZE(WINDOW_G);
-        dst->pre_g = (secp256k1_ge_storage (*)[])checked_malloc(cb, size);
-        memcpy(dst->pre_g, src->pre_g, size);
+static void secp256k1_ecmult_context_finalize_memcpy(secp256k1_ecmult_context *dst, const secp256k1_ecmult_context *src) {
+    if (src->pre_g != NULL) {
+        /* We cast to void* first to suppress a -Wcast-align warning. */
+        dst->pre_g = (secp256k1_ge_storage (*)[])(void*)((unsigned char*)dst + ((unsigned char*)(src->pre_g) - (unsigned char*)src));
     }
 #ifdef USE_ENDOMORPHISM
-    if (src->pre_g_128 == NULL) {
-        dst->pre_g_128 = NULL;
-    } else {
-        size_t size = sizeof((*dst->pre_g_128)[0]) * ECMULT_TABLE_SIZE(WINDOW_G);
-        dst->pre_g_128 = (secp256k1_ge_storage (*)[])checked_malloc(cb, size);
-        memcpy(dst->pre_g_128, src->pre_g_128, size);
+    if (src->pre_g_128 != NULL) {
+        dst->pre_g_128 = (secp256k1_ge_storage (*)[])(void*)((unsigned char*)dst + ((unsigned char*)(src->pre_g_128) - (unsigned char*)src));
     }
 #endif
 }
@@ -218,10 +384,6 @@ static int secp256k1_ecmult_context_is_built(const secp256k1_ecmult_context *ctx
 }
 
 static void secp256k1_ecmult_context_clear(secp256k1_ecmult_context *ctx) {
-    free(ctx->pre_g);
-#ifdef USE_ENDOMORPHISM
-    free(ctx->pre_g_128);
-#endif
     secp256k1_ecmult_context_init(ctx);
 }
 
@@ -233,7 +395,7 @@ static void secp256k1_ecmult_context_clear(secp256k1_ecmult_context *ctx) {
  *    than the number of bits in the (absolute value) of the input.
  */
 static int secp256k1_ecmult_wnaf(int *wnaf, int len, const secp256k1_scalar *a, int w) {
-    secp256k1_scalar s = *a;
+    secp256k1_scalar s;
     int last_set_bit = -1;
     int bit = 0;
     int sign = 1;
@@ -246,6 +408,7 @@ static int secp256k1_ecmult_wnaf(int *wnaf, int len, const secp256k1_scalar *a,
 
     memset(wnaf, 0, len * sizeof(wnaf[0]));
 
+    s = *a;
     if (secp256k1_scalar_get_bits(&s, 255, 1)) {
         secp256k1_scalar_negate(&s, &s);
         sign = -1;
@@ -278,55 +441,83 @@ static int secp256k1_ecmult_wnaf(int *wnaf, int len, const secp256k1_scalar *a,
     CHECK(carry == 0);
     while (bit < 256) {
         CHECK(secp256k1_scalar_get_bits(&s, bit++, 1) == 0);
-    } 
+    }
 #endif
     return last_set_bit + 1;
 }
 
-static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej *r, const secp256k1_gej *a, const secp256k1_scalar *na, const secp256k1_scalar *ng) {
-    secp256k1_ge pre_a[ECMULT_TABLE_SIZE(WINDOW_A)];
-    secp256k1_ge tmpa;
-    secp256k1_fe Z;
+struct secp256k1_strauss_point_state {
 #ifdef USE_ENDOMORPHISM
-    secp256k1_ge pre_a_lam[ECMULT_TABLE_SIZE(WINDOW_A)];
     secp256k1_scalar na_1, na_lam;
-    /* Splitted G factors. */
-    secp256k1_scalar ng_1, ng_128;
     int wnaf_na_1[130];
     int wnaf_na_lam[130];
     int bits_na_1;
     int bits_na_lam;
-    int wnaf_ng_1[129];
-    int bits_ng_1;
-    int wnaf_ng_128[129];
-    int bits_ng_128;
 #else
     int wnaf_na[256];
     int bits_na;
+#endif
+    size_t input_pos;
+};
+
+struct secp256k1_strauss_state {
+    secp256k1_gej* prej;
+    secp256k1_fe* zr;
+    secp256k1_ge* pre_a;
+#ifdef USE_ENDOMORPHISM
+    secp256k1_ge* pre_a_lam;
+#endif
+    struct secp256k1_strauss_point_state* ps;
+};
+
+static void secp256k1_ecmult_strauss_wnaf(const secp256k1_ecmult_context *ctx, const struct secp256k1_strauss_state *state, secp256k1_gej *r, int num, const secp256k1_gej *a, const secp256k1_scalar *na, const secp256k1_scalar *ng) {
+    secp256k1_ge tmpa;
+    secp256k1_fe Z;
+#ifdef USE_ENDOMORPHISM
+    /* Splitted G factors. */
+    secp256k1_scalar ng_1, ng_128;
+    int wnaf_ng_1[129];
+    int bits_ng_1 = 0;
+    int wnaf_ng_128[129];
+    int bits_ng_128 = 0;
+#else
     int wnaf_ng[256];
-    int bits_ng;
+    int bits_ng = 0;
 #endif
     int i;
-    int bits;
+    int bits = 0;
+    int np;
+    int no = 0;
 
+    for (np = 0; np < num; ++np) {
+        if (secp256k1_scalar_is_zero(&na[np]) || secp256k1_gej_is_infinity(&a[np])) {
+            continue;
+        }
+        state->ps[no].input_pos = np;
 #ifdef USE_ENDOMORPHISM
-    /* split na into na_1 and na_lam (where na = na_1 + na_lam*lambda, and na_1 and na_lam are ~128 bit) */
-    secp256k1_scalar_split_lambda(&na_1, &na_lam, na);
-
-    /* build wnaf representation for na_1 and na_lam. */
-    bits_na_1   = secp256k1_ecmult_wnaf(wnaf_na_1,   130, &na_1,   WINDOW_A);
-    bits_na_lam = secp256k1_ecmult_wnaf(wnaf_na_lam, 130, &na_lam, WINDOW_A);
-    VERIFY_CHECK(bits_na_1 <= 130);
-    VERIFY_CHECK(bits_na_lam <= 130);
-    bits = bits_na_1;
-    if (bits_na_lam > bits) {
-        bits = bits_na_lam;
-    }
+        /* split na into na_1 and na_lam (where na = na_1 + na_lam*lambda, and na_1 and na_lam are ~128 bit) */
+        secp256k1_scalar_split_lambda(&state->ps[no].na_1, &state->ps[no].na_lam, &na[np]);
+
+        /* build wnaf representation for na_1 and na_lam. */
+        state->ps[no].bits_na_1   = secp256k1_ecmult_wnaf(state->ps[no].wnaf_na_1,   130, &state->ps[no].na_1,   WINDOW_A);
+        state->ps[no].bits_na_lam = secp256k1_ecmult_wnaf(state->ps[no].wnaf_na_lam, 130, &state->ps[no].na_lam, WINDOW_A);
+        VERIFY_CHECK(state->ps[no].bits_na_1 <= 130);
+        VERIFY_CHECK(state->ps[no].bits_na_lam <= 130);
+        if (state->ps[no].bits_na_1 > bits) {
+            bits = state->ps[no].bits_na_1;
+        }
+        if (state->ps[no].bits_na_lam > bits) {
+            bits = state->ps[no].bits_na_lam;
+        }
 #else
-    /* build wnaf representation for na. */
-    bits_na     = secp256k1_ecmult_wnaf(wnaf_na,     256, na,      WINDOW_A);
-    bits = bits_na;
+        /* build wnaf representation for na. */
+        state->ps[no].bits_na     = secp256k1_ecmult_wnaf(state->ps[no].wnaf_na,     256, &na[np],      WINDOW_A);
+        if (state->ps[no].bits_na > bits) {
+            bits = state->ps[no].bits_na;
+        }
 #endif
+        ++no;
+    }
 
     /* Calculate odd multiples of a.
      * All multiples are brought to the same Z 'denominator', which is stored
@@ -338,29 +529,51 @@ static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej
      * of 1/Z, so we can use secp256k1_gej_add_zinv_var, which uses the same
      * isomorphism to efficiently add with a known Z inverse.
      */
-    secp256k1_ecmult_odd_multiples_table_globalz_windowa(pre_a, &Z, a);
+    if (no > 0) {
+        /* Compute the odd multiples in Jacobian form. */
+        secp256k1_ecmult_odd_multiples_table(ECMULT_TABLE_SIZE(WINDOW_A), state->prej, state->zr, &a[state->ps[0].input_pos]);
+        for (np = 1; np < no; ++np) {
+            secp256k1_gej tmp = a[state->ps[np].input_pos];
+#ifdef VERIFY
+            secp256k1_fe_normalize_var(&(state->prej[(np - 1) * ECMULT_TABLE_SIZE(WINDOW_A) + ECMULT_TABLE_SIZE(WINDOW_A) - 1].z));
+#endif
+            secp256k1_gej_rescale(&tmp, &(state->prej[(np - 1) * ECMULT_TABLE_SIZE(WINDOW_A) + ECMULT_TABLE_SIZE(WINDOW_A) - 1].z));
+            secp256k1_ecmult_odd_multiples_table(ECMULT_TABLE_SIZE(WINDOW_A), state->prej + np * ECMULT_TABLE_SIZE(WINDOW_A), state->zr + np * ECMULT_TABLE_SIZE(WINDOW_A), &tmp);
+            secp256k1_fe_mul(state->zr + np * ECMULT_TABLE_SIZE(WINDOW_A), state->zr + np * ECMULT_TABLE_SIZE(WINDOW_A), &(a[state->ps[np].input_pos].z));
+        }
+        /* Bring them to the same Z denominator. */
+        secp256k1_ge_globalz_set_table_gej(ECMULT_TABLE_SIZE(WINDOW_A) * no, state->pre_a, &Z, state->prej, state->zr);
+    } else {
+        secp256k1_fe_set_int(&Z, 1);
+    }
 
 #ifdef USE_ENDOMORPHISM
-    for (i = 0; i < ECMULT_TABLE_SIZE(WINDOW_A); i++) {
-        secp256k1_ge_mul_lambda(&pre_a_lam[i], &pre_a[i]);
+    for (np = 0; np < no; ++np) {
+        for (i = 0; i < ECMULT_TABLE_SIZE(WINDOW_A); i++) {
+            secp256k1_ge_mul_lambda(&state->pre_a_lam[np * ECMULT_TABLE_SIZE(WINDOW_A) + i], &state->pre_a[np * ECMULT_TABLE_SIZE(WINDOW_A) + i]);
+        }
     }
 
-    /* split ng into ng_1 and ng_128 (where gn = gn_1 + gn_128*2^128, and gn_1 and gn_128 are ~128 bit) */
-    secp256k1_scalar_split_128(&ng_1, &ng_128, ng);
+    if (ng) {
+        /* split ng into ng_1 and ng_128 (where gn = gn_1 + gn_128*2^128, and gn_1 and gn_128 are ~128 bit) */
+        secp256k1_scalar_split_128(&ng_1, &ng_128, ng);
 
-    /* Build wnaf representation for ng_1 and ng_128 */
-    bits_ng_1   = secp256k1_ecmult_wnaf(wnaf_ng_1,   129, &ng_1,   WINDOW_G);
-    bits_ng_128 = secp256k1_ecmult_wnaf(wnaf_ng_128, 129, &ng_128, WINDOW_G);
-    if (bits_ng_1 > bits) {
-        bits = bits_ng_1;
-    }
-    if (bits_ng_128 > bits) {
-        bits = bits_ng_128;
+        /* Build wnaf representation for ng_1 and ng_128 */
+        bits_ng_1   = secp256k1_ecmult_wnaf(wnaf_ng_1,   129, &ng_1,   WINDOW_G);
+        bits_ng_128 = secp256k1_ecmult_wnaf(wnaf_ng_128, 129, &ng_128, WINDOW_G);
+        if (bits_ng_1 > bits) {
+            bits = bits_ng_1;
+        }
+        if (bits_ng_128 > bits) {
+            bits = bits_ng_128;
+        }
     }
 #else
-    bits_ng     = secp256k1_ecmult_wnaf(wnaf_ng,     256, ng,      WINDOW_G);
-    if (bits_ng > bits) {
-        bits = bits_ng;
+    if (ng) {
+        bits_ng     = secp256k1_ecmult_wnaf(wnaf_ng,     256, ng,      WINDOW_G);
+        if (bits_ng > bits) {
+            bits = bits_ng;
+        }
     }
 #endif
 
@@ -370,13 +583,15 @@ static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej
         int n;
         secp256k1_gej_double_var(r, r, NULL);
 #ifdef USE_ENDOMORPHISM
-        if (i < bits_na_1 && (n = wnaf_na_1[i])) {
-            ECMULT_TABLE_GET_GE(&tmpa, pre_a, n, WINDOW_A);
-            secp256k1_gej_add_ge_var(r, r, &tmpa, NULL);
-        }
-        if (i < bits_na_lam && (n = wnaf_na_lam[i])) {
-            ECMULT_TABLE_GET_GE(&tmpa, pre_a_lam, n, WINDOW_A);
-            secp256k1_gej_add_ge_var(r, r, &tmpa, NULL);
+        for (np = 0; np < no; ++np) {
+            if (i < state->ps[np].bits_na_1 && (n = state->ps[np].wnaf_na_1[i])) {
+                ECMULT_TABLE_GET_GE(&tmpa, state->pre_a + np * ECMULT_TABLE_SIZE(WINDOW_A), n, WINDOW_A);
+                secp256k1_gej_add_ge_var(r, r, &tmpa, NULL);
+            }
+            if (i < state->ps[np].bits_na_lam && (n = state->ps[np].wnaf_na_lam[i])) {
+                ECMULT_TABLE_GET_GE(&tmpa, state->pre_a_lam + np * ECMULT_TABLE_SIZE(WINDOW_A), n, WINDOW_A);
+                secp256k1_gej_add_ge_var(r, r, &tmpa, NULL);
+            }
         }
         if (i < bits_ng_1 && (n = wnaf_ng_1[i])) {
             ECMULT_TABLE_GET_GE_STORAGE(&tmpa, *ctx->pre_g, n, WINDOW_G);
@@ -387,9 +602,11 @@ static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej
             secp256k1_gej_add_zinv_var(r, r, &tmpa, &Z);
         }
 #else
-        if (i < bits_na && (n = wnaf_na[i])) {
-            ECMULT_TABLE_GET_GE(&tmpa, pre_a, n, WINDOW_A);
-            secp256k1_gej_add_ge_var(r, r, &tmpa, NULL);
+        for (np = 0; np < no; ++np) {
+            if (i < state->ps[np].bits_na && (n = state->ps[np].wnaf_na[i])) {
+                ECMULT_TABLE_GET_GE(&tmpa, state->pre_a + np * ECMULT_TABLE_SIZE(WINDOW_A), n, WINDOW_A);
+                secp256k1_gej_add_ge_var(r, r, &tmpa, NULL);
+            }
         }
         if (i < bits_ng && (n = wnaf_ng[i])) {
             ECMULT_TABLE_GET_GE_STORAGE(&tmpa, *ctx->pre_g, n, WINDOW_G);
@@ -403,4 +620,597 @@ static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej
     }
 }
 
+static void secp256k1_ecmult(const secp256k1_ecmult_context *ctx, secp256k1_gej *r, const secp256k1_gej *a, const secp256k1_scalar *na, const secp256k1_scalar *ng) {
+    secp256k1_gej prej[ECMULT_TABLE_SIZE(WINDOW_A)];
+    secp256k1_fe zr[ECMULT_TABLE_SIZE(WINDOW_A)];
+    secp256k1_ge pre_a[ECMULT_TABLE_SIZE(WINDOW_A)];
+    struct secp256k1_strauss_point_state ps[1];
+#ifdef USE_ENDOMORPHISM
+    secp256k1_ge pre_a_lam[ECMULT_TABLE_SIZE(WINDOW_A)];
+#endif
+    struct secp256k1_strauss_state state;
+
+    state.prej = prej;
+    state.zr = zr;
+    state.pre_a = pre_a;
+#ifdef USE_ENDOMORPHISM
+    state.pre_a_lam = pre_a_lam;
 #endif
+    state.ps = ps;
+    secp256k1_ecmult_strauss_wnaf(ctx, &state, r, 1, a, na, ng);
+}
+
+static size_t secp256k1_strauss_scratch_size(size_t n_points) {
+#ifdef USE_ENDOMORPHISM
+    static const size_t point_size = (2 * sizeof(secp256k1_ge) + sizeof(secp256k1_gej) + sizeof(secp256k1_fe)) * ECMULT_TABLE_SIZE(WINDOW_A) + sizeof(struct secp256k1_strauss_point_state) + sizeof(secp256k1_gej) + sizeof(secp256k1_scalar);
+#else
+    static const size_t point_size = (sizeof(secp256k1_ge) + sizeof(secp256k1_gej) + sizeof(secp256k1_fe)) * ECMULT_TABLE_SIZE(WINDOW_A) + sizeof(struct secp256k1_strauss_point_state) + sizeof(secp256k1_gej) + sizeof(secp256k1_scalar);
+#endif
+    return n_points*point_size;
+}
+
+static int secp256k1_ecmult_strauss_batch(const secp256k1_callback* error_callback, const secp256k1_ecmult_context *ctx, secp256k1_scratch *scratch, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n_points, size_t cb_offset) {
+    secp256k1_gej* points;
+    secp256k1_scalar* scalars;
+    struct secp256k1_strauss_state state;
+    size_t i;
+    const size_t scratch_checkpoint = secp256k1_scratch_checkpoint(error_callback, scratch);
+
+    secp256k1_gej_set_infinity(r);
+    if (inp_g_sc == NULL && n_points == 0) {
+        return 1;
+    }
+
+    points = (secp256k1_gej*)secp256k1_scratch_alloc(error_callback, scratch, n_points * sizeof(secp256k1_gej));
+    scalars = (secp256k1_scalar*)secp256k1_scratch_alloc(error_callback, scratch, n_points * sizeof(secp256k1_scalar));
+    state.prej = (secp256k1_gej*)secp256k1_scratch_alloc(error_callback, scratch, n_points * ECMULT_TABLE_SIZE(WINDOW_A) * sizeof(secp256k1_gej));
+    state.zr = (secp256k1_fe*)secp256k1_scratch_alloc(error_callback, scratch, n_points * ECMULT_TABLE_SIZE(WINDOW_A) * sizeof(secp256k1_fe));
+#ifdef USE_ENDOMORPHISM
+    state.pre_a = (secp256k1_ge*)secp256k1_scratch_alloc(error_callback, scratch, n_points * 2 * ECMULT_TABLE_SIZE(WINDOW_A) * sizeof(secp256k1_ge));
+    state.pre_a_lam = state.pre_a + n_points * ECMULT_TABLE_SIZE(WINDOW_A);
+#else
+    state.pre_a = (secp256k1_ge*)secp256k1_scratch_alloc(error_callback, scratch, n_points * ECMULT_TABLE_SIZE(WINDOW_A) * sizeof(secp256k1_ge));
+#endif
+    state.ps = (struct secp256k1_strauss_point_state*)secp256k1_scratch_alloc(error_callback, scratch, n_points * sizeof(struct secp256k1_strauss_point_state));
+
+    if (points == NULL || scalars == NULL || state.prej == NULL || state.zr == NULL || state.pre_a == NULL) {
+        secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+        return 0;
+    }
+
+    for (i = 0; i < n_points; i++) {
+        secp256k1_ge point;
+        if (!cb(&scalars[i], &point, i+cb_offset, cbdata)) {
+            secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+            return 0;
+        }
+        secp256k1_gej_set_ge(&points[i], &point);
+    }
+    secp256k1_ecmult_strauss_wnaf(ctx, &state, r, n_points, points, scalars, inp_g_sc);
+    secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+    return 1;
+}
+
+/* Wrapper for secp256k1_ecmult_multi_func interface */
+static int secp256k1_ecmult_strauss_batch_single(const secp256k1_callback* error_callback, const secp256k1_ecmult_context *actx, secp256k1_scratch *scratch, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n) {
+    return secp256k1_ecmult_strauss_batch(error_callback, actx, scratch, r, inp_g_sc, cb, cbdata, n, 0);
+}
+
+static size_t secp256k1_strauss_max_points(const secp256k1_callback* error_callback, secp256k1_scratch *scratch) {
+    return secp256k1_scratch_max_allocation(error_callback, scratch, STRAUSS_SCRATCH_OBJECTS) / secp256k1_strauss_scratch_size(1);
+}
+
+/** Convert a number to WNAF notation.
+ *  The number becomes represented by sum(2^{wi} * wnaf[i], i=0..WNAF_SIZE(w)+1) - return_val.
+ *  It has the following guarantees:
+ *  - each wnaf[i] is either 0 or an odd integer between -(1 << w) and (1 << w)
+ *  - the number of words set is always WNAF_SIZE(w)
+ *  - the returned skew is 0 or 1
+ */
+static int secp256k1_wnaf_fixed(int *wnaf, const secp256k1_scalar *s, int w) {
+    int skew = 0;
+    int pos;
+    int max_pos;
+    int last_w;
+    const secp256k1_scalar *work = s;
+
+    if (secp256k1_scalar_is_zero(s)) {
+        for (pos = 0; pos < WNAF_SIZE(w); pos++) {
+            wnaf[pos] = 0;
+        }
+        return 0;
+    }
+
+    if (secp256k1_scalar_is_even(s)) {
+        skew = 1;
+    }
+
+    wnaf[0] = secp256k1_scalar_get_bits_var(work, 0, w) + skew;
+    /* Compute last window size. Relevant when window size doesn't divide the
+     * number of bits in the scalar */
+    last_w = WNAF_BITS - (WNAF_SIZE(w) - 1) * w;
+
+    /* Store the position of the first nonzero word in max_pos to allow
+     * skipping leading zeros when calculating the wnaf. */
+    for (pos = WNAF_SIZE(w) - 1; pos > 0; pos--) {
+        int val = secp256k1_scalar_get_bits_var(work, pos * w, pos == WNAF_SIZE(w)-1 ? last_w : w);
+        if(val != 0) {
+            break;
+        }
+        wnaf[pos] = 0;
+    }
+    max_pos = pos;
+    pos = 1;
+
+    while (pos <= max_pos) {
+        int val = secp256k1_scalar_get_bits_var(work, pos * w, pos == WNAF_SIZE(w)-1 ? last_w : w);
+        if ((val & 1) == 0) {
+            wnaf[pos - 1] -= (1 << w);
+            wnaf[pos] = (val + 1);
+        } else {
+            wnaf[pos] = val;
+        }
+        /* Set a coefficient to zero if it is 1 or -1 and the proceeding digit
+         * is strictly negative or strictly positive respectively. Only change
+         * coefficients at previous positions because above code assumes that
+         * wnaf[pos - 1] is odd.
+         */
+        if (pos >= 2 && ((wnaf[pos - 1] == 1 && wnaf[pos - 2] < 0) || (wnaf[pos - 1] == -1 && wnaf[pos - 2] > 0))) {
+            if (wnaf[pos - 1] == 1) {
+                wnaf[pos - 2] += 1 << w;
+            } else {
+                wnaf[pos - 2] -= 1 << w;
+            }
+            wnaf[pos - 1] = 0;
+        }
+        ++pos;
+    }
+
+    return skew;
+}
+
+struct secp256k1_pippenger_point_state {
+    int skew_na;
+    size_t input_pos;
+};
+
+struct secp256k1_pippenger_state {
+    int *wnaf_na;
+    struct secp256k1_pippenger_point_state* ps;
+};
+
+/*
+ * pippenger_wnaf computes the result of a multi-point multiplication as
+ * follows: The scalars are brought into wnaf with n_wnaf elements each. Then
+ * for every i < n_wnaf, first each point is added to a "bucket" corresponding
+ * to the point's wnaf[i]. Second, the buckets are added together such that
+ * r += 1*bucket[0] + 3*bucket[1] + 5*bucket[2] + ...
+ */
+static int secp256k1_ecmult_pippenger_wnaf(secp256k1_gej *buckets, int bucket_window, struct secp256k1_pippenger_state *state, secp256k1_gej *r, const secp256k1_scalar *sc, const secp256k1_ge *pt, size_t num) {
+    size_t n_wnaf = WNAF_SIZE(bucket_window+1);
+    size_t np;
+    size_t no = 0;
+    int i;
+    int j;
+
+    for (np = 0; np < num; ++np) {
+        if (secp256k1_scalar_is_zero(&sc[np]) || secp256k1_ge_is_infinity(&pt[np])) {
+            continue;
+        }
+        state->ps[no].input_pos = np;
+        state->ps[no].skew_na = secp256k1_wnaf_fixed(&state->wnaf_na[no*n_wnaf], &sc[np], bucket_window+1);
+        no++;
+    }
+    secp256k1_gej_set_infinity(r);
+
+    if (no == 0) {
+        return 1;
+    }
+
+    for (i = n_wnaf - 1; i >= 0; i--) {
+        secp256k1_gej running_sum;
+
+        for(j = 0; j < ECMULT_TABLE_SIZE(bucket_window+2); j++) {
+            secp256k1_gej_set_infinity(&buckets[j]);
+        }
+
+        for (np = 0; np < no; ++np) {
+            int n = state->wnaf_na[np*n_wnaf + i];
+            struct secp256k1_pippenger_point_state point_state = state->ps[np];
+            secp256k1_ge tmp;
+            int idx;
+
+            if (i == 0) {
+                /* correct for wnaf skew */
+                int skew = point_state.skew_na;
+                if (skew) {
+                    secp256k1_ge_neg(&tmp, &pt[point_state.input_pos]);
+                    secp256k1_gej_add_ge_var(&buckets[0], &buckets[0], &tmp, NULL);
+                }
+            }
+            if (n > 0) {
+                idx = (n - 1)/2;
+                secp256k1_gej_add_ge_var(&buckets[idx], &buckets[idx], &pt[point_state.input_pos], NULL);
+            } else if (n < 0) {
+                idx = -(n + 1)/2;
+                secp256k1_ge_neg(&tmp, &pt[point_state.input_pos]);
+                secp256k1_gej_add_ge_var(&buckets[idx], &buckets[idx], &tmp, NULL);
+            }
+        }
+
+        for(j = 0; j < bucket_window; j++) {
+            secp256k1_gej_double_var(r, r, NULL);
+        }
+
+        secp256k1_gej_set_infinity(&running_sum);
+        /* Accumulate the sum: bucket[0] + 3*bucket[1] + 5*bucket[2] + 7*bucket[3] + ...
+         *                   = bucket[0] +   bucket[1] +   bucket[2] +   bucket[3] + ...
+         *                   +         2 *  (bucket[1] + 2*bucket[2] + 3*bucket[3] + ...)
+         * using an intermediate running sum:
+         * running_sum = bucket[0] +   bucket[1] +   bucket[2] + ...
+         *
+         * The doubling is done implicitly by deferring the final window doubling (of 'r').
+         */
+        for(j = ECMULT_TABLE_SIZE(bucket_window+2) - 1; j > 0; j--) {
+            secp256k1_gej_add_var(&running_sum, &running_sum, &buckets[j], NULL);
+            secp256k1_gej_add_var(r, r, &running_sum, NULL);
+        }
+
+        secp256k1_gej_add_var(&running_sum, &running_sum, &buckets[0], NULL);
+        secp256k1_gej_double_var(r, r, NULL);
+        secp256k1_gej_add_var(r, r, &running_sum, NULL);
+    }
+    return 1;
+}
+
+/**
+ * Returns optimal bucket_window (number of bits of a scalar represented by a
+ * set of buckets) for a given number of points.
+ */
+static int secp256k1_pippenger_bucket_window(size_t n) {
+#ifdef USE_ENDOMORPHISM
+    if (n <= 1) {
+        return 1;
+    } else if (n <= 4) {
+        return 2;
+    } else if (n <= 20) {
+        return 3;
+    } else if (n <= 57) {
+        return 4;
+    } else if (n <= 136) {
+        return 5;
+    } else if (n <= 235) {
+        return 6;
+    } else if (n <= 1260) {
+        return 7;
+    } else if (n <= 4420) {
+        return 9;
+    } else if (n <= 7880) {
+        return 10;
+    } else if (n <= 16050) {
+        return 11;
+    } else {
+        return PIPPENGER_MAX_BUCKET_WINDOW;
+    }
+#else
+    if (n <= 1) {
+        return 1;
+    } else if (n <= 11) {
+        return 2;
+    } else if (n <= 45) {
+        return 3;
+    } else if (n <= 100) {
+        return 4;
+    } else if (n <= 275) {
+        return 5;
+    } else if (n <= 625) {
+        return 6;
+    } else if (n <= 1850) {
+        return 7;
+    } else if (n <= 3400) {
+        return 8;
+    } else if (n <= 9630) {
+        return 9;
+    } else if (n <= 17900) {
+        return 10;
+    } else if (n <= 32800) {
+        return 11;
+    } else {
+        return PIPPENGER_MAX_BUCKET_WINDOW;
+    }
+#endif
+}
+
+/**
+ * Returns the maximum optimal number of points for a bucket_window.
+ */
+static size_t secp256k1_pippenger_bucket_window_inv(int bucket_window) {
+    switch(bucket_window) {
+#ifdef USE_ENDOMORPHISM
+        case 1: return 1;
+        case 2: return 4;
+        case 3: return 20;
+        case 4: return 57;
+        case 5: return 136;
+        case 6: return 235;
+        case 7: return 1260;
+        case 8: return 1260;
+        case 9: return 4420;
+        case 10: return 7880;
+        case 11: return 16050;
+        case PIPPENGER_MAX_BUCKET_WINDOW: return SIZE_MAX;
+#else
+        case 1: return 1;
+        case 2: return 11;
+        case 3: return 45;
+        case 4: return 100;
+        case 5: return 275;
+        case 6: return 625;
+        case 7: return 1850;
+        case 8: return 3400;
+        case 9: return 9630;
+        case 10: return 17900;
+        case 11: return 32800;
+        case PIPPENGER_MAX_BUCKET_WINDOW: return SIZE_MAX;
+#endif
+    }
+    return 0;
+}
+
+
+#ifdef USE_ENDOMORPHISM
+SECP256K1_INLINE static void secp256k1_ecmult_endo_split(secp256k1_scalar *s1, secp256k1_scalar *s2, secp256k1_ge *p1, secp256k1_ge *p2) {
+    secp256k1_scalar tmp = *s1;
+    secp256k1_scalar_split_lambda(s1, s2, &tmp);
+    secp256k1_ge_mul_lambda(p2, p1);
+
+    if (secp256k1_scalar_is_high(s1)) {
+        secp256k1_scalar_negate(s1, s1);
+        secp256k1_ge_neg(p1, p1);
+    }
+    if (secp256k1_scalar_is_high(s2)) {
+        secp256k1_scalar_negate(s2, s2);
+        secp256k1_ge_neg(p2, p2);
+    }
+}
+#endif
+
+/**
+ * Returns the scratch size required for a given number of points (excluding
+ * base point G) without considering alignment.
+ */
+static size_t secp256k1_pippenger_scratch_size(size_t n_points, int bucket_window) {
+#ifdef USE_ENDOMORPHISM
+    size_t entries = 2*n_points + 2;
+#else
+    size_t entries = n_points + 1;
+#endif
+    size_t entry_size = sizeof(secp256k1_ge) + sizeof(secp256k1_scalar) + sizeof(struct secp256k1_pippenger_point_state) + (WNAF_SIZE(bucket_window+1)+1)*sizeof(int);
+    return (sizeof(secp256k1_gej) << bucket_window) + sizeof(struct secp256k1_pippenger_state) + entries * entry_size;
+}
+
+static int secp256k1_ecmult_pippenger_batch(const secp256k1_callback* error_callback, const secp256k1_ecmult_context *ctx, secp256k1_scratch *scratch, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n_points, size_t cb_offset) {
+    const size_t scratch_checkpoint = secp256k1_scratch_checkpoint(error_callback, scratch);
+    /* Use 2(n+1) with the endomorphism, n+1 without, when calculating batch
+     * sizes. The reason for +1 is that we add the G scalar to the list of
+     * other scalars. */
+#ifdef USE_ENDOMORPHISM
+    size_t entries = 2*n_points + 2;
+#else
+    size_t entries = n_points + 1;
+#endif
+    secp256k1_ge *points;
+    secp256k1_scalar *scalars;
+    secp256k1_gej *buckets;
+    struct secp256k1_pippenger_state *state_space;
+    size_t idx = 0;
+    size_t point_idx = 0;
+    int i, j;
+    int bucket_window;
+
+    (void)ctx;
+    secp256k1_gej_set_infinity(r);
+    if (inp_g_sc == NULL && n_points == 0) {
+        return 1;
+    }
+
+    bucket_window = secp256k1_pippenger_bucket_window(n_points);
+    points = (secp256k1_ge *) secp256k1_scratch_alloc(error_callback, scratch, entries * sizeof(*points));
+    scalars = (secp256k1_scalar *) secp256k1_scratch_alloc(error_callback, scratch, entries * sizeof(*scalars));
+    state_space = (struct secp256k1_pippenger_state *) secp256k1_scratch_alloc(error_callback, scratch, sizeof(*state_space));
+    if (points == NULL || scalars == NULL || state_space == NULL) {
+        secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+        return 0;
+    }
+
+    state_space->ps = (struct secp256k1_pippenger_point_state *) secp256k1_scratch_alloc(error_callback, scratch, entries * sizeof(*state_space->ps));
+    state_space->wnaf_na = (int *) secp256k1_scratch_alloc(error_callback, scratch, entries*(WNAF_SIZE(bucket_window+1)) * sizeof(int));
+    buckets = (secp256k1_gej *) secp256k1_scratch_alloc(error_callback, scratch, (1<<bucket_window) * sizeof(*buckets));
+    if (state_space->ps == NULL || state_space->wnaf_na == NULL || buckets == NULL) {
+        secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+        return 0;
+    }
+
+    if (inp_g_sc != NULL) {
+        scalars[0] = *inp_g_sc;
+        points[0] = secp256k1_ge_const_g;
+        idx++;
+#ifdef USE_ENDOMORPHISM
+        secp256k1_ecmult_endo_split(&scalars[0], &scalars[1], &points[0], &points[1]);
+        idx++;
+#endif
+    }
+
+    while (point_idx < n_points) {
+        if (!cb(&scalars[idx], &points[idx], point_idx + cb_offset, cbdata)) {
+            secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+            return 0;
+        }
+        idx++;
+#ifdef USE_ENDOMORPHISM
+        secp256k1_ecmult_endo_split(&scalars[idx - 1], &scalars[idx], &points[idx - 1], &points[idx]);
+        idx++;
+#endif
+        point_idx++;
+    }
+
+    secp256k1_ecmult_pippenger_wnaf(buckets, bucket_window, state_space, r, scalars, points, idx);
+
+    /* Clear data */
+    for(i = 0; (size_t)i < idx; i++) {
+        secp256k1_scalar_clear(&scalars[i]);
+        state_space->ps[i].skew_na = 0;
+        for(j = 0; j < WNAF_SIZE(bucket_window+1); j++) {
+            state_space->wnaf_na[i * WNAF_SIZE(bucket_window+1) + j] = 0;
+        }
+    }
+    for(i = 0; i < 1<<bucket_window; i++) {
+        secp256k1_gej_clear(&buckets[i]);
+    }
+    secp256k1_scratch_apply_checkpoint(error_callback, scratch, scratch_checkpoint);
+    return 1;
+}
+
+/* Wrapper for secp256k1_ecmult_multi_func interface */
+static int secp256k1_ecmult_pippenger_batch_single(const secp256k1_callback* error_callback, const secp256k1_ecmult_context *actx, secp256k1_scratch *scratch, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n) {
+    return secp256k1_ecmult_pippenger_batch(error_callback, actx, scratch, r, inp_g_sc, cb, cbdata, n, 0);
+}
+
+/**
+ * Returns the maximum number of points in addition to G that can be used with
+ * a given scratch space. The function ensures that fewer points may also be
+ * used.
+ */
+static size_t secp256k1_pippenger_max_points(const secp256k1_callback* error_callback, secp256k1_scratch *scratch) {
+    size_t max_alloc = secp256k1_scratch_max_allocation(error_callback, scratch, PIPPENGER_SCRATCH_OBJECTS);
+    int bucket_window;
+    size_t res = 0;
+
+    for (bucket_window = 1; bucket_window <= PIPPENGER_MAX_BUCKET_WINDOW; bucket_window++) {
+        size_t n_points;
+        size_t max_points = secp256k1_pippenger_bucket_window_inv(bucket_window);
+        size_t space_for_points;
+        size_t space_overhead;
+        size_t entry_size = sizeof(secp256k1_ge) + sizeof(secp256k1_scalar) + sizeof(struct secp256k1_pippenger_point_state) + (WNAF_SIZE(bucket_window+1)+1)*sizeof(int);
+
+#ifdef USE_ENDOMORPHISM
+        entry_size = 2*entry_size;
+#endif
+        space_overhead = (sizeof(secp256k1_gej) << bucket_window) + entry_size + sizeof(struct secp256k1_pippenger_state);
+        if (space_overhead > max_alloc) {
+            break;
+        }
+        space_for_points = max_alloc - space_overhead;
+
+        n_points = space_for_points/entry_size;
+        n_points = n_points > max_points ? max_points : n_points;
+        if (n_points > res) {
+            res = n_points;
+        }
+        if (n_points < max_points) {
+            /* A larger bucket_window may support even more points. But if we
+             * would choose that then the caller couldn't safely use any number
+             * smaller than what this function returns */
+            break;
+        }
+    }
+    return res;
+}
+
+/* Computes ecmult_multi by simply multiplying and adding each point. Does not
+ * require a scratch space */
+static int secp256k1_ecmult_multi_simple_var(const secp256k1_ecmult_context *ctx, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n_points) {
+    size_t point_idx;
+    secp256k1_scalar szero;
+    secp256k1_gej tmpj;
+
+    secp256k1_scalar_set_int(&szero, 0);
+    secp256k1_gej_set_infinity(r);
+    secp256k1_gej_set_infinity(&tmpj);
+    /* r = inp_g_sc*G */
+    secp256k1_ecmult(ctx, r, &tmpj, &szero, inp_g_sc);
+    for (point_idx = 0; point_idx < n_points; point_idx++) {
+        secp256k1_ge point;
+        secp256k1_gej pointj;
+        secp256k1_scalar scalar;
+        if (!cb(&scalar, &point, point_idx, cbdata)) {
+            return 0;
+        }
+        /* r += scalar*point */
+        secp256k1_gej_set_ge(&pointj, &point);
+        secp256k1_ecmult(ctx, &tmpj, &pointj, &scalar, NULL);
+        secp256k1_gej_add_var(r, r, &tmpj, NULL);
+    }
+    return 1;
+}
+
+/* Compute the number of batches and the batch size given the maximum batch size and the
+ * total number of points */
+static int secp256k1_ecmult_multi_batch_size_helper(size_t *n_batches, size_t *n_batch_points, size_t max_n_batch_points, size_t n) {
+    if (max_n_batch_points == 0) {
+        return 0;
+    }
+    if (max_n_batch_points > ECMULT_MAX_POINTS_PER_BATCH) {
+        max_n_batch_points = ECMULT_MAX_POINTS_PER_BATCH;
+    }
+    if (n == 0) {
+        *n_batches = 0;
+        *n_batch_points = 0;
+        return 1;
+    }
+    /* Compute ceil(n/max_n_batch_points) and ceil(n/n_batches) */
+    *n_batches = 1 + (n - 1) / max_n_batch_points;
+    *n_batch_points = 1 + (n - 1) / *n_batches;
+    return 1;
+}
+
+typedef int (*secp256k1_ecmult_multi_func)(const secp256k1_callback* error_callback, const secp256k1_ecmult_context*, secp256k1_scratch*, secp256k1_gej*, const secp256k1_scalar*, secp256k1_ecmult_multi_callback cb, void*, size_t);
+static int secp256k1_ecmult_multi_var(const secp256k1_callback* error_callback, const secp256k1_ecmult_context *ctx, secp256k1_scratch *scratch, secp256k1_gej *r, const secp256k1_scalar *inp_g_sc, secp256k1_ecmult_multi_callback cb, void *cbdata, size_t n) {
+    size_t i;
+
+    int (*f)(const secp256k1_callback* error_callback, const secp256k1_ecmult_context*, secp256k1_scratch*, secp256k1_gej*, const secp256k1_scalar*, secp256k1_ecmult_multi_callback cb, void*, size_t, size_t);
+    size_t n_batches;
+    size_t n_batch_points;
+
+    secp256k1_gej_set_infinity(r);
+    if (inp_g_sc == NULL && n == 0) {
+        return 1;
+    } else if (n == 0) {
+        secp256k1_scalar szero;
+        secp256k1_scalar_set_int(&szero, 0);
+        secp256k1_ecmult(ctx, r, r, &szero, inp_g_sc);
+        return 1;
+    }
+    if (scratch == NULL) {
+        return secp256k1_ecmult_multi_simple_var(ctx, r, inp_g_sc, cb, cbdata, n);
+    }
+
+    /* Compute the batch sizes for Pippenger's algorithm given a scratch space. If it's greater than
+     * a threshold use Pippenger's algorithm. Otherwise use Strauss' algorithm.
+     * As a first step check if there's enough space for Pippenger's algo (which requires less space
+     * than Strauss' algo) and if not, use the simple algorithm. */
+    if (!secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, secp256k1_pippenger_max_points(error_callback, scratch), n)) {
+        return secp256k1_ecmult_multi_simple_var(ctx, r, inp_g_sc, cb, cbdata, n);
+    }
+    if (n_batch_points >= ECMULT_PIPPENGER_THRESHOLD) {
+        f = secp256k1_ecmult_pippenger_batch;
+    } else {
+        if (!secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, secp256k1_strauss_max_points(error_callback, scratch), n)) {
+            return secp256k1_ecmult_multi_simple_var(ctx, r, inp_g_sc, cb, cbdata, n);
+        }
+        f = secp256k1_ecmult_strauss_batch;
+    }
+    for(i = 0; i < n_batches; i++) {
+        size_t nbp = n < n_batch_points ? n : n_batch_points;
+        size_t offset = n_batch_points*i;
+        secp256k1_gej tmp;
+        if (!f(error_callback, ctx, scratch, &tmp, i == 0 ? inp_g_sc : NULL, cb, cbdata, nbp, offset)) {
+            return 0;
+        }
+        secp256k1_gej_add_var(r, r, &tmp, NULL);
+        n -= nbp;
+    }
+    return 1;
+}
+
+#endif /* SECP256K1_ECMULT_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field.h b/crypto/secp256k1/libsecp256k1/src/field.h
index bbb1ee866..8283e4b18 100644
--- a/crypto/secp256k1/libsecp256k1/src/field.h
+++ b/crypto/secp256k1/libsecp256k1/src/field.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_
-#define _SECP256K1_FIELD_
+#ifndef SECP256K1_FIELD_H
+#define SECP256K1_FIELD_H
 
 /** Field element module.
  *
@@ -32,10 +32,12 @@
 
 #include "util.h"
 
-/** Normalize a field element. */
+/** Normalize a field element. This brings the field element to a canonical representation, reduces
+ *  its magnitude to 1, and reduces it modulo field size `p`.
+ */
 static void secp256k1_fe_normalize(secp256k1_fe *r);
 
-/** Weakly normalize a field element: reduce it magnitude to 1, but don't fully normalize. */
+/** Weakly normalize a field element: reduce its magnitude to 1, but don't fully normalize. */
 static void secp256k1_fe_normalize_weak(secp256k1_fe *r);
 
 /** Normalize a field element, without constant-time guarantee. */
@@ -129,4 +131,4 @@ static void secp256k1_fe_storage_cmov(secp256k1_fe_storage *r, const secp256k1_f
 /** If flag is true, set *r equal to *a; otherwise leave it. Constant-time. */
 static void secp256k1_fe_cmov(secp256k1_fe *r, const secp256k1_fe *a, int flag);
 
-#endif
+#endif /* SECP256K1_FIELD_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_10x26.h b/crypto/secp256k1/libsecp256k1/src/field_10x26.h
index 61ee1e096..5ff03c8ab 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_10x26.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_10x26.h
@@ -4,13 +4,15 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_REPR_
-#define _SECP256K1_FIELD_REPR_
+#ifndef SECP256K1_FIELD_REPR_H
+#define SECP256K1_FIELD_REPR_H
 
 #include <stdint.h>
 
 typedef struct {
-    /* X = sum(i=0..9, elem[i]*2^26) mod n */
+    /* X = sum(i=0..9, n[i]*2^(i*26)) mod p
+     * where p = 2^256 - 0x1000003D1
+     */
     uint32_t n[10];
 #ifdef VERIFY
     int magnitude;
@@ -44,4 +46,5 @@ typedef struct {
 
 #define SECP256K1_FE_STORAGE_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {{ (d0), (d1), (d2), (d3), (d4), (d5), (d6), (d7) }}
 #define SECP256K1_FE_STORAGE_CONST_GET(d) d.n[7], d.n[6], d.n[5], d.n[4],d.n[3], d.n[2], d.n[1], d.n[0]
-#endif
+
+#endif /* SECP256K1_FIELD_REPR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_10x26_impl.h b/crypto/secp256k1/libsecp256k1/src/field_10x26_impl.h
index 5fb092f1b..39304245d 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_10x26_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_10x26_impl.h
@@ -4,11 +4,10 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_REPR_IMPL_H_
-#define _SECP256K1_FIELD_REPR_IMPL_H_
+#ifndef SECP256K1_FIELD_REPR_IMPL_H
+#define SECP256K1_FIELD_REPR_IMPL_H
 
 #include "util.h"
-#include "num.h"
 #include "field.h"
 
 #ifdef VERIFY
@@ -321,45 +320,69 @@ static int secp256k1_fe_cmp_var(const secp256k1_fe *a, const secp256k1_fe *b) {
 }
 
 static int secp256k1_fe_set_b32(secp256k1_fe *r, const unsigned char *a) {
-    int i;
-    r->n[0] = r->n[1] = r->n[2] = r->n[3] = r->n[4] = 0;
-    r->n[5] = r->n[6] = r->n[7] = r->n[8] = r->n[9] = 0;
-    for (i=0; i<32; i++) {
-        int j;
-        for (j=0; j<4; j++) {
-            int limb = (8*i+2*j)/26;
-            int shift = (8*i+2*j)%26;
-            r->n[limb] |= (uint32_t)((a[31-i] >> (2*j)) & 0x3) << shift;
-        }
-    }
-    if (r->n[9] == 0x3FFFFFUL && (r->n[8] & r->n[7] & r->n[6] & r->n[5] & r->n[4] & r->n[3] & r->n[2]) == 0x3FFFFFFUL && (r->n[1] + 0x40UL + ((r->n[0] + 0x3D1UL) >> 26)) > 0x3FFFFFFUL) {
-        return 0;
-    }
+    int ret;
+    r->n[0] = (uint32_t)a[31] | ((uint32_t)a[30] << 8) | ((uint32_t)a[29] << 16) | ((uint32_t)(a[28] & 0x3) << 24);
+    r->n[1] = (uint32_t)((a[28] >> 2) & 0x3f) | ((uint32_t)a[27] << 6) | ((uint32_t)a[26] << 14) | ((uint32_t)(a[25] & 0xf) << 22);
+    r->n[2] = (uint32_t)((a[25] >> 4) & 0xf) | ((uint32_t)a[24] << 4) | ((uint32_t)a[23] << 12) | ((uint32_t)(a[22] & 0x3f) << 20);
+    r->n[3] = (uint32_t)((a[22] >> 6) & 0x3) | ((uint32_t)a[21] << 2) | ((uint32_t)a[20] << 10) | ((uint32_t)a[19] << 18);
+    r->n[4] = (uint32_t)a[18] | ((uint32_t)a[17] << 8) | ((uint32_t)a[16] << 16) | ((uint32_t)(a[15] & 0x3) << 24);
+    r->n[5] = (uint32_t)((a[15] >> 2) & 0x3f) | ((uint32_t)a[14] << 6) | ((uint32_t)a[13] << 14) | ((uint32_t)(a[12] & 0xf) << 22);
+    r->n[6] = (uint32_t)((a[12] >> 4) & 0xf) | ((uint32_t)a[11] << 4) | ((uint32_t)a[10] << 12) | ((uint32_t)(a[9] & 0x3f) << 20);
+    r->n[7] = (uint32_t)((a[9] >> 6) & 0x3) | ((uint32_t)a[8] << 2) | ((uint32_t)a[7] << 10) | ((uint32_t)a[6] << 18);
+    r->n[8] = (uint32_t)a[5] | ((uint32_t)a[4] << 8) | ((uint32_t)a[3] << 16) | ((uint32_t)(a[2] & 0x3) << 24);
+    r->n[9] = (uint32_t)((a[2] >> 2) & 0x3f) | ((uint32_t)a[1] << 6) | ((uint32_t)a[0] << 14);
+
+    ret = !((r->n[9] == 0x3FFFFFUL) & ((r->n[8] & r->n[7] & r->n[6] & r->n[5] & r->n[4] & r->n[3] & r->n[2]) == 0x3FFFFFFUL) & ((r->n[1] + 0x40UL + ((r->n[0] + 0x3D1UL) >> 26)) > 0x3FFFFFFUL));
 #ifdef VERIFY
     r->magnitude = 1;
-    r->normalized = 1;
-    secp256k1_fe_verify(r);
+    if (ret) {
+        r->normalized = 1;
+        secp256k1_fe_verify(r);
+    } else {
+        r->normalized = 0;
+    }
 #endif
-    return 1;
+    return ret;
 }
 
 /** Convert a field element to a 32-byte big endian value. Requires the input to be normalized */
 static void secp256k1_fe_get_b32(unsigned char *r, const secp256k1_fe *a) {
-    int i;
 #ifdef VERIFY
     VERIFY_CHECK(a->normalized);
     secp256k1_fe_verify(a);
 #endif
-    for (i=0; i<32; i++) {
-        int j;
-        int c = 0;
-        for (j=0; j<4; j++) {
-            int limb = (8*i+2*j)/26;
-            int shift = (8*i+2*j)%26;
-            c |= ((a->n[limb] >> shift) & 0x3) << (2 * j);
-        }
-        r[31-i] = c;
-    }
+    r[0] = (a->n[9] >> 14) & 0xff;
+    r[1] = (a->n[9] >> 6) & 0xff;
+    r[2] = ((a->n[9] & 0x3F) << 2) | ((a->n[8] >> 24) & 0x3);
+    r[3] = (a->n[8] >> 16) & 0xff;
+    r[4] = (a->n[8] >> 8) & 0xff;
+    r[5] = a->n[8] & 0xff;
+    r[6] = (a->n[7] >> 18) & 0xff;
+    r[7] = (a->n[7] >> 10) & 0xff;
+    r[8] = (a->n[7] >> 2) & 0xff;
+    r[9] = ((a->n[7] & 0x3) << 6) | ((a->n[6] >> 20) & 0x3f);
+    r[10] = (a->n[6] >> 12) & 0xff;
+    r[11] = (a->n[6] >> 4) & 0xff;
+    r[12] = ((a->n[6] & 0xf) << 4) | ((a->n[5] >> 22) & 0xf);
+    r[13] = (a->n[5] >> 14) & 0xff;
+    r[14] = (a->n[5] >> 6) & 0xff;
+    r[15] = ((a->n[5] & 0x3f) << 2) | ((a->n[4] >> 24) & 0x3);
+    r[16] = (a->n[4] >> 16) & 0xff;
+    r[17] = (a->n[4] >> 8) & 0xff;
+    r[18] = a->n[4] & 0xff;
+    r[19] = (a->n[3] >> 18) & 0xff;
+    r[20] = (a->n[3] >> 10) & 0xff;
+    r[21] = (a->n[3] >> 2) & 0xff;
+    r[22] = ((a->n[3] & 0x3) << 6) | ((a->n[2] >> 20) & 0x3f);
+    r[23] = (a->n[2] >> 12) & 0xff;
+    r[24] = (a->n[2] >> 4) & 0xff;
+    r[25] = ((a->n[2] & 0xf) << 4) | ((a->n[1] >> 22) & 0xf);
+    r[26] = (a->n[1] >> 14) & 0xff;
+    r[27] = (a->n[1] >> 6) & 0xff;
+    r[28] = ((a->n[1] & 0x3f) << 2) | ((a->n[0] >> 24) & 0x3);
+    r[29] = (a->n[0] >> 16) & 0xff;
+    r[30] = (a->n[0] >> 8) & 0xff;
+    r[31] = a->n[0] & 0xff;
 }
 
 SECP256K1_INLINE static void secp256k1_fe_negate(secp256k1_fe *r, const secp256k1_fe *a, int m) {
@@ -465,7 +488,8 @@ SECP256K1_INLINE static void secp256k1_fe_mul_inner(uint32_t *r, const uint32_t
     VERIFY_BITS(b[9], 26);
 
     /** [... a b c] is a shorthand for ... + a<<52 + b<<26 + c<<0 mod n.
-     *  px is a shorthand for sum(a[i]*b[x-i], i=0..x).
+     *  for 0 <= x <= 9, px is a shorthand for sum(a[i]*b[x-i], i=0..x).
+     *  for 9 <= x <= 18, px is a shorthand for sum(a[i]*b[x-i], i=(x-9)..9)
      *  Note that [x 0 0 0 0 0 0 0 0 0 0] = [x*R1 x*R0].
      */
 
@@ -1048,6 +1072,7 @@ static void secp256k1_fe_mul(secp256k1_fe *r, const secp256k1_fe *a, const secp2
     secp256k1_fe_verify(a);
     secp256k1_fe_verify(b);
     VERIFY_CHECK(r != b);
+    VERIFY_CHECK(a != b);
 #endif
     secp256k1_fe_mul_inner(r->n, a->n, b->n);
 #ifdef VERIFY
@@ -1085,10 +1110,10 @@ static SECP256K1_INLINE void secp256k1_fe_cmov(secp256k1_fe *r, const secp256k1_
     r->n[8] = (r->n[8] & mask0) | (a->n[8] & mask1);
     r->n[9] = (r->n[9] & mask0) | (a->n[9] & mask1);
 #ifdef VERIFY
-    if (a->magnitude > r->magnitude) {
+    if (flag) {
         r->magnitude = a->magnitude;
+        r->normalized = a->normalized;
     }
-    r->normalized &= a->normalized;
 #endif
 }
 
@@ -1137,4 +1162,4 @@ static SECP256K1_INLINE void secp256k1_fe_from_storage(secp256k1_fe *r, const se
 #endif
 }
 
-#endif
+#endif /* SECP256K1_FIELD_REPR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_5x52.h b/crypto/secp256k1/libsecp256k1/src/field_5x52.h
index 8e69a560d..fc5bfe357 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_5x52.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_5x52.h
@@ -4,13 +4,15 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_REPR_
-#define _SECP256K1_FIELD_REPR_
+#ifndef SECP256K1_FIELD_REPR_H
+#define SECP256K1_FIELD_REPR_H
 
 #include <stdint.h>
 
 typedef struct {
-    /* X = sum(i=0..4, elem[i]*2^52) mod n */
+    /* X = sum(i=0..4, n[i]*2^(i*52)) mod p
+     * where p = 2^256 - 0x1000003D1
+     */
     uint64_t n[5];
 #ifdef VERIFY
     int magnitude;
@@ -44,4 +46,4 @@ typedef struct {
     (d6) | (((uint64_t)(d7)) << 32) \
 }}
 
-#endif
+#endif /* SECP256K1_FIELD_REPR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_5x52_asm_impl.h b/crypto/secp256k1/libsecp256k1/src/field_5x52_asm_impl.h
index 98cc004bf..1fc3171f6 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_5x52_asm_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_5x52_asm_impl.h
@@ -11,8 +11,8 @@
  * - December 2014, Pieter Wuille: converted from YASM to GCC inline assembly
  */
 
-#ifndef _SECP256K1_FIELD_INNER5X52_IMPL_H_
-#define _SECP256K1_FIELD_INNER5X52_IMPL_H_
+#ifndef SECP256K1_FIELD_INNER5X52_IMPL_H
+#define SECP256K1_FIELD_INNER5X52_IMPL_H
 
 SECP256K1_INLINE static void secp256k1_fe_mul_inner(uint64_t *r, const uint64_t *a, const uint64_t * SECP256K1_RESTRICT b) {
 /**
@@ -499,4 +499,4 @@ __asm__ __volatile__(
 );
 }
 
-#endif
+#endif /* SECP256K1_FIELD_INNER5X52_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_5x52_impl.h b/crypto/secp256k1/libsecp256k1/src/field_5x52_impl.h
index dd88f38c7..71aa550e4 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_5x52_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_5x52_impl.h
@@ -4,15 +4,14 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_REPR_IMPL_H_
-#define _SECP256K1_FIELD_REPR_IMPL_H_
+#ifndef SECP256K1_FIELD_REPR_IMPL_H
+#define SECP256K1_FIELD_REPR_IMPL_H
 
 #if defined HAVE_CONFIG_H
 #include "libsecp256k1-config.h"
 #endif
 
 #include "util.h"
-#include "num.h"
 #include "field.h"
 
 #if defined(USE_ASM_X86_64)
@@ -284,44 +283,92 @@ static int secp256k1_fe_cmp_var(const secp256k1_fe *a, const secp256k1_fe *b) {
 }
 
 static int secp256k1_fe_set_b32(secp256k1_fe *r, const unsigned char *a) {
-    int i;
-    r->n[0] = r->n[1] = r->n[2] = r->n[3] = r->n[4] = 0;
-    for (i=0; i<32; i++) {
-        int j;
-        for (j=0; j<2; j++) {
-            int limb = (8*i+4*j)/52;
-            int shift = (8*i+4*j)%52;
-            r->n[limb] |= (uint64_t)((a[31-i] >> (4*j)) & 0xF) << shift;
-        }
-    }
-    if (r->n[4] == 0x0FFFFFFFFFFFFULL && (r->n[3] & r->n[2] & r->n[1]) == 0xFFFFFFFFFFFFFULL && r->n[0] >= 0xFFFFEFFFFFC2FULL) {
-        return 0;
-    }
+    int ret;
+    r->n[0] = (uint64_t)a[31]
+            | ((uint64_t)a[30] << 8)
+            | ((uint64_t)a[29] << 16)
+            | ((uint64_t)a[28] << 24)
+            | ((uint64_t)a[27] << 32)
+            | ((uint64_t)a[26] << 40)
+            | ((uint64_t)(a[25] & 0xF)  << 48);
+    r->n[1] = (uint64_t)((a[25] >> 4) & 0xF)
+            | ((uint64_t)a[24] << 4)
+            | ((uint64_t)a[23] << 12)
+            | ((uint64_t)a[22] << 20)
+            | ((uint64_t)a[21] << 28)
+            | ((uint64_t)a[20] << 36)
+            | ((uint64_t)a[19] << 44);
+    r->n[2] = (uint64_t)a[18]
+            | ((uint64_t)a[17] << 8)
+            | ((uint64_t)a[16] << 16)
+            | ((uint64_t)a[15] << 24)
+            | ((uint64_t)a[14] << 32)
+            | ((uint64_t)a[13] << 40)
+            | ((uint64_t)(a[12] & 0xF) << 48);
+    r->n[3] = (uint64_t)((a[12] >> 4) & 0xF)
+            | ((uint64_t)a[11] << 4)
+            | ((uint64_t)a[10] << 12)
+            | ((uint64_t)a[9]  << 20)
+            | ((uint64_t)a[8]  << 28)
+            | ((uint64_t)a[7]  << 36)
+            | ((uint64_t)a[6]  << 44);
+    r->n[4] = (uint64_t)a[5]
+            | ((uint64_t)a[4] << 8)
+            | ((uint64_t)a[3] << 16)
+            | ((uint64_t)a[2] << 24)
+            | ((uint64_t)a[1] << 32)
+            | ((uint64_t)a[0] << 40);
+    ret = !((r->n[4] == 0x0FFFFFFFFFFFFULL) & ((r->n[3] & r->n[2] & r->n[1]) == 0xFFFFFFFFFFFFFULL) & (r->n[0] >= 0xFFFFEFFFFFC2FULL));
 #ifdef VERIFY
     r->magnitude = 1;
-    r->normalized = 1;
-    secp256k1_fe_verify(r);
+    if (ret) {
+        r->normalized = 1;
+        secp256k1_fe_verify(r);
+    } else {
+        r->normalized = 0;
+    }
 #endif
-    return 1;
+    return ret;
 }
 
 /** Convert a field element to a 32-byte big endian value. Requires the input to be normalized */
 static void secp256k1_fe_get_b32(unsigned char *r, const secp256k1_fe *a) {
-    int i;
 #ifdef VERIFY
     VERIFY_CHECK(a->normalized);
     secp256k1_fe_verify(a);
 #endif
-    for (i=0; i<32; i++) {
-        int j;
-        int c = 0;
-        for (j=0; j<2; j++) {
-            int limb = (8*i+4*j)/52;
-            int shift = (8*i+4*j)%52;
-            c |= ((a->n[limb] >> shift) & 0xF) << (4 * j);
-        }
-        r[31-i] = c;
-    }
+    r[0] = (a->n[4] >> 40) & 0xFF;
+    r[1] = (a->n[4] >> 32) & 0xFF;
+    r[2] = (a->n[4] >> 24) & 0xFF;
+    r[3] = (a->n[4] >> 16) & 0xFF;
+    r[4] = (a->n[4] >> 8) & 0xFF;
+    r[5] = a->n[4] & 0xFF;
+    r[6] = (a->n[3] >> 44) & 0xFF;
+    r[7] = (a->n[3] >> 36) & 0xFF;
+    r[8] = (a->n[3] >> 28) & 0xFF;
+    r[9] = (a->n[3] >> 20) & 0xFF;
+    r[10] = (a->n[3] >> 12) & 0xFF;
+    r[11] = (a->n[3] >> 4) & 0xFF;
+    r[12] = ((a->n[2] >> 48) & 0xF) | ((a->n[3] & 0xF) << 4);
+    r[13] = (a->n[2] >> 40) & 0xFF;
+    r[14] = (a->n[2] >> 32) & 0xFF;
+    r[15] = (a->n[2] >> 24) & 0xFF;
+    r[16] = (a->n[2] >> 16) & 0xFF;
+    r[17] = (a->n[2] >> 8) & 0xFF;
+    r[18] = a->n[2] & 0xFF;
+    r[19] = (a->n[1] >> 44) & 0xFF;
+    r[20] = (a->n[1] >> 36) & 0xFF;
+    r[21] = (a->n[1] >> 28) & 0xFF;
+    r[22] = (a->n[1] >> 20) & 0xFF;
+    r[23] = (a->n[1] >> 12) & 0xFF;
+    r[24] = (a->n[1] >> 4) & 0xFF;
+    r[25] = ((a->n[0] >> 48) & 0xF) | ((a->n[1] & 0xF) << 4);
+    r[26] = (a->n[0] >> 40) & 0xFF;
+    r[27] = (a->n[0] >> 32) & 0xFF;
+    r[28] = (a->n[0] >> 24) & 0xFF;
+    r[29] = (a->n[0] >> 16) & 0xFF;
+    r[30] = (a->n[0] >> 8) & 0xFF;
+    r[31] = a->n[0] & 0xFF;
 }
 
 SECP256K1_INLINE static void secp256k1_fe_negate(secp256k1_fe *r, const secp256k1_fe *a, int m) {
@@ -377,6 +424,7 @@ static void secp256k1_fe_mul(secp256k1_fe *r, const secp256k1_fe *a, const secp2
     secp256k1_fe_verify(a);
     secp256k1_fe_verify(b);
     VERIFY_CHECK(r != b);
+    VERIFY_CHECK(a != b);
 #endif
     secp256k1_fe_mul_inner(r->n, a->n, b->n);
 #ifdef VERIFY
@@ -409,10 +457,10 @@ static SECP256K1_INLINE void secp256k1_fe_cmov(secp256k1_fe *r, const secp256k1_
     r->n[3] = (r->n[3] & mask0) | (a->n[3] & mask1);
     r->n[4] = (r->n[4] & mask0) | (a->n[4] & mask1);
 #ifdef VERIFY
-    if (a->magnitude > r->magnitude) {
+    if (flag) {
         r->magnitude = a->magnitude;
+        r->normalized = a->normalized;
     }
-    r->normalized &= a->normalized;
 #endif
 }
 
@@ -448,4 +496,4 @@ static SECP256K1_INLINE void secp256k1_fe_from_storage(secp256k1_fe *r, const se
 #endif
 }
 
-#endif
+#endif /* SECP256K1_FIELD_REPR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_5x52_int128_impl.h b/crypto/secp256k1/libsecp256k1/src/field_5x52_int128_impl.h
index 0bf22bdd3..bcbfb92ac 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_5x52_int128_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_5x52_int128_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_INNER5X52_IMPL_H_
-#define _SECP256K1_FIELD_INNER5X52_IMPL_H_
+#ifndef SECP256K1_FIELD_INNER5X52_IMPL_H
+#define SECP256K1_FIELD_INNER5X52_IMPL_H
 
 #include <stdint.h>
 
@@ -32,9 +32,11 @@ SECP256K1_INLINE static void secp256k1_fe_mul_inner(uint64_t *r, const uint64_t
     VERIFY_BITS(b[3], 56);
     VERIFY_BITS(b[4], 52);
     VERIFY_CHECK(r != b);
+    VERIFY_CHECK(a != b);
 
     /*  [... a b c] is a shorthand for ... + a<<104 + b<<52 + c<<0 mod n.
-     *  px is a shorthand for sum(a[i]*b[x-i], i=0..x).
+     *  for 0 <= x <= 4, px is a shorthand for sum(a[i]*b[x-i], i=0..x).
+     *  for 4 <= x <= 8, px is a shorthand for sum(a[i]*b[x-i], i=(x-4)..4)
      *  Note that [x 0 0 0 0 0] = [x*R].
      */
 
@@ -274,4 +276,4 @@ SECP256K1_INLINE static void secp256k1_fe_sqr_inner(uint64_t *r, const uint64_t
     /* [r4 r3 r2 r1 r0] = [p8 p7 p6 p5 p4 p3 p2 p1 p0] */
 }
 
-#endif
+#endif /* SECP256K1_FIELD_INNER5X52_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/field_impl.h b/crypto/secp256k1/libsecp256k1/src/field_impl.h
index 5127b279b..485921a60 100644
--- a/crypto/secp256k1/libsecp256k1/src/field_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/field_impl.h
@@ -4,14 +4,15 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_FIELD_IMPL_H_
-#define _SECP256K1_FIELD_IMPL_H_
+#ifndef SECP256K1_FIELD_IMPL_H
+#define SECP256K1_FIELD_IMPL_H
 
 #if defined HAVE_CONFIG_H
 #include "libsecp256k1-config.h"
 #endif
 
 #include "util.h"
+#include "num.h"
 
 #if defined(USE_FIELD_10X26)
 #include "field_10x26_impl.h"
@@ -48,6 +49,8 @@ static int secp256k1_fe_sqrt(secp256k1_fe *r, const secp256k1_fe *a) {
     secp256k1_fe x2, x3, x6, x9, x11, x22, x44, x88, x176, x220, x223, t1;
     int j;
 
+    VERIFY_CHECK(r != a);
+
     /** The binary representation of (p + 1)/4 has 3 blocks of 1s, with lengths in
      *  { 2, 22, 223 }. Use an addition chain to calculate 2^n - 1 for each block:
      *  1, [2], 3, 6, 9, 11, [22], 44, 88, 176, 220, [223]
@@ -312,4 +315,6 @@ static int secp256k1_fe_is_quad_var(const secp256k1_fe *a) {
 #endif
 }
 
-#endif
+static const secp256k1_fe secp256k1_fe_one = SECP256K1_FE_CONST(0, 0, 0, 0, 0, 0, 0, 1);
+
+#endif /* SECP256K1_FIELD_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/gen_context.c b/crypto/secp256k1/libsecp256k1/src/gen_context.c
index 1835fd491..539f574bf 100644
--- a/crypto/secp256k1/libsecp256k1/src/gen_context.c
+++ b/crypto/secp256k1/libsecp256k1/src/gen_context.c
@@ -4,10 +4,16 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
+// Autotools creates libsecp256k1-config.h, of which ECMULT_GEN_PREC_BITS is needed.
+// ifndef guard so downstream users can define their own if they do not use autotools.
+#if !defined(ECMULT_GEN_PREC_BITS)
+#include "libsecp256k1-config.h"
+#endif
 #define USE_BASIC_CONFIG 1
-
 #include "basic-config.h"
+
 #include "include/secp256k1.h"
+#include "util.h"
 #include "field_impl.h"
 #include "scalar_impl.h"
 #include "group_impl.h"
@@ -26,6 +32,7 @@ static const secp256k1_callback default_error_callback = {
 
 int main(int argc, char **argv) {
     secp256k1_ecmult_gen_context ctx;
+    void *prealloc, *base;
     int inner;
     int outer;
     FILE* fp;
@@ -38,26 +45,31 @@ int main(int argc, char **argv) {
         fprintf(stderr, "Could not open src/ecmult_static_context.h for writing!\n");
         return -1;
     }
-    
+
     fprintf(fp, "#ifndef _SECP256K1_ECMULT_STATIC_CONTEXT_\n");
     fprintf(fp, "#define _SECP256K1_ECMULT_STATIC_CONTEXT_\n");
-    fprintf(fp, "#include \"group.h\"\n");
+    fprintf(fp, "#include \"src/group.h\"\n");
     fprintf(fp, "#define SC SECP256K1_GE_STORAGE_CONST\n");
-    fprintf(fp, "static const secp256k1_ge_storage secp256k1_ecmult_static_context[64][16] = {\n");
+    fprintf(fp, "#if ECMULT_GEN_PREC_N != %d || ECMULT_GEN_PREC_G != %d\n", ECMULT_GEN_PREC_N, ECMULT_GEN_PREC_G);
+    fprintf(fp, "   #error configuration mismatch, invalid ECMULT_GEN_PREC_N, ECMULT_GEN_PREC_G. Try deleting ecmult_static_context.h before the build.\n");
+    fprintf(fp, "#endif\n");
+    fprintf(fp, "static const secp256k1_ge_storage secp256k1_ecmult_static_context[ECMULT_GEN_PREC_N][ECMULT_GEN_PREC_G] = {\n");
 
+    base = checked_malloc(&default_error_callback, SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE);
+    prealloc = base;
     secp256k1_ecmult_gen_context_init(&ctx);
-    secp256k1_ecmult_gen_context_build(&ctx, &default_error_callback);
-    for(outer = 0; outer != 64; outer++) {
+    secp256k1_ecmult_gen_context_build(&ctx, &prealloc);
+    for(outer = 0; outer != ECMULT_GEN_PREC_N; outer++) {
         fprintf(fp,"{\n");
-        for(inner = 0; inner != 16; inner++) {
+        for(inner = 0; inner != ECMULT_GEN_PREC_G; inner++) {
             fprintf(fp,"    SC(%uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu, %uu)", SECP256K1_GE_STORAGE_CONST_GET((*ctx.prec)[outer][inner]));
-            if (inner != 15) {
+            if (inner != ECMULT_GEN_PREC_G - 1) {
                 fprintf(fp,",\n");
             } else {
                 fprintf(fp,"\n");
             }
         }
-        if (outer != 63) {
+        if (outer != ECMULT_GEN_PREC_N - 1) {
             fprintf(fp,"},\n");
         } else {
             fprintf(fp,"}\n");
@@ -65,10 +77,11 @@ int main(int argc, char **argv) {
     }
     fprintf(fp,"};\n");
     secp256k1_ecmult_gen_context_clear(&ctx);
-    
+    free(base);
+
     fprintf(fp, "#undef SC\n");
     fprintf(fp, "#endif\n");
     fclose(fp);
-    
+
     return 0;
 }
diff --git a/crypto/secp256k1/libsecp256k1/src/group.h b/crypto/secp256k1/libsecp256k1/src/group.h
index 4957b248f..ded4e1dab 100644
--- a/crypto/secp256k1/libsecp256k1/src/group.h
+++ b/crypto/secp256k1/libsecp256k1/src/group.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_GROUP_
-#define _SECP256K1_GROUP_
+#ifndef SECP256K1_GROUP_H
+#define SECP256K1_GROUP_H
 
 #include "num.h"
 #include "field.h"
@@ -65,12 +65,7 @@ static void secp256k1_ge_neg(secp256k1_ge *r, const secp256k1_ge *a);
 static void secp256k1_ge_set_gej(secp256k1_ge *r, secp256k1_gej *a);
 
 /** Set a batch of group elements equal to the inputs given in jacobian coordinates */
-static void secp256k1_ge_set_all_gej_var(secp256k1_ge *r, const secp256k1_gej *a, size_t len, const secp256k1_callback *cb);
-
-/** Set a batch of group elements equal to the inputs given in jacobian
- *  coordinates (with known z-ratios). zr must contain the known z-ratios such
- *  that mul(a[i].z, zr[i+1]) == a[i+1].z. zr[0] is ignored. */
-static void secp256k1_ge_set_table_gej_var(secp256k1_ge *r, const secp256k1_gej *a, const secp256k1_fe *zr, size_t len);
+static void secp256k1_ge_set_all_gej_var(secp256k1_ge *r, const secp256k1_gej *a, size_t len);
 
 /** Bring a batch inputs given in jacobian coordinates (with known z-ratios) to
  *  the same global z "denominator". zr must contain the known z-ratios such
@@ -79,6 +74,9 @@ static void secp256k1_ge_set_table_gej_var(secp256k1_ge *r, const secp256k1_gej
  *  stored in globalz. */
 static void secp256k1_ge_globalz_set_table_gej(size_t len, secp256k1_ge *r, secp256k1_fe *globalz, const secp256k1_gej *a, const secp256k1_fe *zr);
 
+/** Set a group element (affine) equal to the point at infinity. */
+static void secp256k1_ge_set_infinity(secp256k1_ge *r);
+
 /** Set a group element (jacobian) equal to the point at infinity. */
 static void secp256k1_gej_set_infinity(secp256k1_gej *r);
 
@@ -97,14 +95,13 @@ static int secp256k1_gej_is_infinity(const secp256k1_gej *a);
 /** Check whether a group element's y coordinate is a quadratic residue. */
 static int secp256k1_gej_has_quad_y_var(const secp256k1_gej *a);
 
-/** Set r equal to the double of a. If rzr is not-NULL, r->z = a->z * *rzr (where infinity means an implicit z = 0).
- * a may not be zero. Constant time. */
-static void secp256k1_gej_double_nonzero(secp256k1_gej *r, const secp256k1_gej *a, secp256k1_fe *rzr);
+/** Set r equal to the double of a, a cannot be infinity. Constant time. */
+static void secp256k1_gej_double_nonzero(secp256k1_gej *r, const secp256k1_gej *a);
 
-/** Set r equal to the double of a. If rzr is not-NULL, r->z = a->z * *rzr (where infinity means an implicit z = 0). */
+/** Set r equal to the double of a. If rzr is not-NULL this sets *rzr such that r->z == a->z * *rzr (where infinity means an implicit z = 0). */
 static void secp256k1_gej_double_var(secp256k1_gej *r, const secp256k1_gej *a, secp256k1_fe *rzr);
 
-/** Set r equal to the sum of a and b. If rzr is non-NULL, r->z = a->z * *rzr (a cannot be infinity in that case). */
+/** Set r equal to the sum of a and b. If rzr is non-NULL this sets *rzr such that r->z == a->z * *rzr (a cannot be infinity in that case). */
 static void secp256k1_gej_add_var(secp256k1_gej *r, const secp256k1_gej *a, const secp256k1_gej *b, secp256k1_fe *rzr);
 
 /** Set r equal to the sum of a and b (with b given in affine coordinates, and not infinity). */
@@ -112,7 +109,7 @@ static void secp256k1_gej_add_ge(secp256k1_gej *r, const secp256k1_gej *a, const
 
 /** Set r equal to the sum of a and b (with b given in affine coordinates). This is more efficient
     than secp256k1_gej_add_var. It is identical to secp256k1_gej_add_ge but without constant-time
-    guarantee, and b is allowed to be infinity. If rzr is non-NULL, r->z = a->z * *rzr (a cannot be infinity in that case). */
+    guarantee, and b is allowed to be infinity. If rzr is non-NULL this sets *rzr such that r->z == a->z * *rzr (a cannot be infinity in that case). */
 static void secp256k1_gej_add_ge_var(secp256k1_gej *r, const secp256k1_gej *a, const secp256k1_ge *b, secp256k1_fe *rzr);
 
 /** Set r equal to the sum of a and b (with the inverse of b's Z coordinate passed as bzinv). */
@@ -141,4 +138,4 @@ static void secp256k1_ge_storage_cmov(secp256k1_ge_storage *r, const secp256k1_g
 /** Rescale a jacobian point by b which must be non-zero. Constant-time. */
 static void secp256k1_gej_rescale(secp256k1_gej *r, const secp256k1_fe *b);
 
-#endif
+#endif /* SECP256K1_GROUP_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/group_impl.h b/crypto/secp256k1/libsecp256k1/src/group_impl.h
index 7d723532f..43b039bec 100644
--- a/crypto/secp256k1/libsecp256k1/src/group_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/group_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_GROUP_IMPL_H_
-#define _SECP256K1_GROUP_IMPL_H_
+#ifndef SECP256K1_GROUP_IMPL_H
+#define SECP256K1_GROUP_IMPL_H
 
 #include "num.h"
 #include "field.h"
@@ -38,22 +38,22 @@
  */
 #if defined(EXHAUSTIVE_TEST_ORDER)
 #  if EXHAUSTIVE_TEST_ORDER == 199
-const secp256k1_ge secp256k1_ge_const_g = SECP256K1_GE_CONST(
+static const secp256k1_ge secp256k1_ge_const_g = SECP256K1_GE_CONST(
     0xFA7CC9A7, 0x0737F2DB, 0xA749DD39, 0x2B4FB069,
     0x3B017A7D, 0xA808C2F1, 0xFB12940C, 0x9EA66C18,
     0x78AC123A, 0x5ED8AEF3, 0x8732BC91, 0x1F3A2868,
     0x48DF246C, 0x808DAE72, 0xCFE52572, 0x7F0501ED
 );
 
-const int CURVE_B = 4;
+static const int CURVE_B = 4;
 #  elif EXHAUSTIVE_TEST_ORDER == 13
-const secp256k1_ge secp256k1_ge_const_g = SECP256K1_GE_CONST(
+static const secp256k1_ge secp256k1_ge_const_g = SECP256K1_GE_CONST(
     0xedc60018, 0xa51a786b, 0x2ea91f4d, 0x4c9416c0,
     0x9de54c3b, 0xa1316554, 0x6cf4345c, 0x7277ef15,
     0x54cb1b6b, 0xdc8c1273, 0x087844ea, 0x43f4603e,
     0x0eaf9a43, 0xf6effe55, 0x939f806d, 0x37adf8ac
 );
-const int CURVE_B = 2;
+static const int CURVE_B = 2;
 #  else
 #    error No known generator for the specified exhaustive test group order.
 #  endif
@@ -68,7 +68,7 @@ static const secp256k1_ge secp256k1_ge_const_g = SECP256K1_GE_CONST(
     0xFD17B448UL, 0xA6855419UL, 0x9C47D08FUL, 0xFB10D4B8UL
 );
 
-const int CURVE_B = 7;
+static const int CURVE_B = 7;
 #endif
 
 static void secp256k1_ge_set_gej_zinv(secp256k1_ge *r, const secp256k1_gej *a, const secp256k1_fe *zi) {
@@ -126,46 +126,43 @@ static void secp256k1_ge_set_gej_var(secp256k1_ge *r, secp256k1_gej *a) {
     r->y = a->y;
 }
 
-static void secp256k1_ge_set_all_gej_var(secp256k1_ge *r, const secp256k1_gej *a, size_t len, const secp256k1_callback *cb) {
-    secp256k1_fe *az;
-    secp256k1_fe *azi;
+static void secp256k1_ge_set_all_gej_var(secp256k1_ge *r, const secp256k1_gej *a, size_t len) {
+    secp256k1_fe u;
     size_t i;
-    size_t count = 0;
-    az = (secp256k1_fe *)checked_malloc(cb, sizeof(secp256k1_fe) * len);
+    size_t last_i = SIZE_MAX;
+
     for (i = 0; i < len; i++) {
         if (!a[i].infinity) {
-            az[count++] = a[i].z;
+            /* Use destination's x coordinates as scratch space */
+            if (last_i == SIZE_MAX) {
+                r[i].x = a[i].z;
+            } else {
+                secp256k1_fe_mul(&r[i].x, &r[last_i].x, &a[i].z);
+            }
+            last_i = i;
         }
     }
+    if (last_i == SIZE_MAX) {
+        return;
+    }
+    secp256k1_fe_inv_var(&u, &r[last_i].x);
 
-    azi = (secp256k1_fe *)checked_malloc(cb, sizeof(secp256k1_fe) * count);
-    secp256k1_fe_inv_all_var(azi, az, count);
-    free(az);
-
-    count = 0;
-    for (i = 0; i < len; i++) {
-        r[i].infinity = a[i].infinity;
+    i = last_i;
+    while (i > 0) {
+        i--;
         if (!a[i].infinity) {
-            secp256k1_ge_set_gej_zinv(&r[i], &a[i], &azi[count++]);
+            secp256k1_fe_mul(&r[last_i].x, &r[i].x, &u);
+            secp256k1_fe_mul(&u, &u, &a[last_i].z);
+            last_i = i;
         }
     }
-    free(azi);
-}
+    VERIFY_CHECK(!a[last_i].infinity);
+    r[last_i].x = u;
 
-static void secp256k1_ge_set_table_gej_var(secp256k1_ge *r, const secp256k1_gej *a, const secp256k1_fe *zr, size_t len) {
-    size_t i = len - 1;
-    secp256k1_fe zi;
-
-    if (len > 0) {
-        /* Compute the inverse of the last z coordinate, and use it to compute the last affine output. */
-        secp256k1_fe_inv(&zi, &a[i].z);
-        secp256k1_ge_set_gej_zinv(&r[i], &a[i], &zi);
-
-        /* Work out way backwards, using the z-ratios to scale the x/y values. */
-        while (i > 0) {
-            secp256k1_fe_mul(&zi, &zi, &zr[i]);
-            i--;
-            secp256k1_ge_set_gej_zinv(&r[i], &a[i], &zi);
+    for (i = 0; i < len; i++) {
+        r[i].infinity = a[i].infinity;
+        if (!a[i].infinity) {
+            secp256k1_ge_set_gej_zinv(&r[i], &a[i], &r[i].x);
         }
     }
 }
@@ -178,6 +175,8 @@ static void secp256k1_ge_globalz_set_table_gej(size_t len, secp256k1_ge *r, secp
         /* The z of the final point gives us the "global Z" for the table. */
         r[i].x = a[i].x;
         r[i].y = a[i].y;
+        /* Ensure all y values are in weak normal form for fast negation of points */
+        secp256k1_fe_normalize_weak(&r[i].y);
         *globalz = a[i].z;
         r[i].infinity = 0;
         zs = zr[i];
@@ -200,6 +199,12 @@ static void secp256k1_gej_set_infinity(secp256k1_gej *r) {
     secp256k1_fe_clear(&r->z);
 }
 
+static void secp256k1_ge_set_infinity(secp256k1_ge *r) {
+    r->infinity = 1;
+    secp256k1_fe_clear(&r->x);
+    secp256k1_fe_clear(&r->y);
+}
+
 static void secp256k1_gej_clear(secp256k1_gej *r) {
     r->infinity = 0;
     secp256k1_fe_clear(&r->x);
@@ -298,7 +303,7 @@ static int secp256k1_ge_is_valid_var(const secp256k1_ge *a) {
     return secp256k1_fe_equal_var(&y2, &x3);
 }
 
-static void secp256k1_gej_double_var(secp256k1_gej *r, const secp256k1_gej *a, secp256k1_fe *rzr) {
+static SECP256K1_INLINE void secp256k1_gej_double_nonzero(secp256k1_gej *r, const secp256k1_gej *a) {
     /* Operations: 3 mul, 4 sqr, 0 normalize, 12 mul_int/add/negate.
      *
      * Note that there is an implementation described at
@@ -307,29 +312,9 @@ static void secp256k1_gej_double_var(secp256k1_gej *r, const secp256k1_gej *a, s
      * mainly because it requires more normalizations.
      */
     secp256k1_fe t1,t2,t3,t4;
-    /** For secp256k1, 2Q is infinity if and only if Q is infinity. This is because if 2Q = infinity,
-     *  Q must equal -Q, or that Q.y == -(Q.y), or Q.y is 0. For a point on y^2 = x^3 + 7 to have
-     *  y=0, x^3 must be -7 mod p. However, -7 has no cube root mod p.
-     *
-     *  Having said this, if this function receives a point on a sextic twist, e.g. by
-     *  a fault attack, it is possible for y to be 0. This happens for y^2 = x^3 + 6,
-     *  since -6 does have a cube root mod p. For this point, this function will not set
-     *  the infinity flag even though the point doubles to infinity, and the result
-     *  point will be gibberish (z = 0 but infinity = 0).
-     */
-    r->infinity = a->infinity;
-    if (r->infinity) {
-        if (rzr != NULL) {
-            secp256k1_fe_set_int(rzr, 1);
-        }
-        return;
-    }
 
-    if (rzr != NULL) {
-        *rzr = a->y;
-        secp256k1_fe_normalize_weak(rzr);
-        secp256k1_fe_mul_int(rzr, 2);
-    }
+    VERIFY_CHECK(!secp256k1_gej_is_infinity(a));
+    r->infinity = 0;
 
     secp256k1_fe_mul(&r->z, &a->z, &a->y);
     secp256k1_fe_mul_int(&r->z, 2);       /* Z' = 2*Y*Z (2) */
@@ -353,9 +338,32 @@ static void secp256k1_gej_double_var(secp256k1_gej *r, const secp256k1_gej *a, s
     secp256k1_fe_add(&r->y, &t2);         /* Y' = 36*X^3*Y^2 - 27*X^6 - 8*Y^4 (4) */
 }
 
-static SECP256K1_INLINE void secp256k1_gej_double_nonzero(secp256k1_gej *r, const secp256k1_gej *a, secp256k1_fe *rzr) {
-    VERIFY_CHECK(!secp256k1_gej_is_infinity(a));
-    secp256k1_gej_double_var(r, a, rzr);
+static void secp256k1_gej_double_var(secp256k1_gej *r, const secp256k1_gej *a, secp256k1_fe *rzr) {
+    /** For secp256k1, 2Q is infinity if and only if Q is infinity. This is because if 2Q = infinity,
+     *  Q must equal -Q, or that Q.y == -(Q.y), or Q.y is 0. For a point on y^2 = x^3 + 7 to have
+     *  y=0, x^3 must be -7 mod p. However, -7 has no cube root mod p.
+     *
+     *  Having said this, if this function receives a point on a sextic twist, e.g. by
+     *  a fault attack, it is possible for y to be 0. This happens for y^2 = x^3 + 6,
+     *  since -6 does have a cube root mod p. For this point, this function will not set
+     *  the infinity flag even though the point doubles to infinity, and the result
+     *  point will be gibberish (z = 0 but infinity = 0).
+     */
+    if (a->infinity) {
+        r->infinity = 1;
+        if (rzr != NULL) {
+            secp256k1_fe_set_int(rzr, 1);
+        }
+        return;
+    }
+
+    if (rzr != NULL) {
+        *rzr = a->y;
+        secp256k1_fe_normalize_weak(rzr);
+        secp256k1_fe_mul_int(rzr, 2);
+    }
+
+    secp256k1_gej_double_nonzero(r, a);
 }
 
 static void secp256k1_gej_add_var(secp256k1_gej *r, const secp256k1_gej *a, const secp256k1_gej *b, secp256k1_fe *rzr) {
@@ -697,4 +705,4 @@ static int secp256k1_gej_has_quad_y_var(const secp256k1_gej *a) {
     return secp256k1_fe_is_quad_var(&yz);
 }
 
-#endif
+#endif /* SECP256K1_GROUP_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/hash.h b/crypto/secp256k1/libsecp256k1/src/hash.h
index fca98cab9..de26e4b89 100644
--- a/crypto/secp256k1/libsecp256k1/src/hash.h
+++ b/crypto/secp256k1/libsecp256k1/src/hash.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_HASH_
-#define _SECP256K1_HASH_
+#ifndef SECP256K1_HASH_H
+#define SECP256K1_HASH_H
 
 #include <stdlib.h>
 #include <stdint.h>
@@ -14,28 +14,28 @@ typedef struct {
     uint32_t s[8];
     uint32_t buf[16]; /* In big endian */
     size_t bytes;
-} secp256k1_sha256_t;
+} secp256k1_sha256;
 
-static void secp256k1_sha256_initialize(secp256k1_sha256_t *hash);
-static void secp256k1_sha256_write(secp256k1_sha256_t *hash, const unsigned char *data, size_t size);
-static void secp256k1_sha256_finalize(secp256k1_sha256_t *hash, unsigned char *out32);
+static void secp256k1_sha256_initialize(secp256k1_sha256 *hash);
+static void secp256k1_sha256_write(secp256k1_sha256 *hash, const unsigned char *data, size_t size);
+static void secp256k1_sha256_finalize(secp256k1_sha256 *hash, unsigned char *out32);
 
 typedef struct {
-    secp256k1_sha256_t inner, outer;
-} secp256k1_hmac_sha256_t;
+    secp256k1_sha256 inner, outer;
+} secp256k1_hmac_sha256;
 
-static void secp256k1_hmac_sha256_initialize(secp256k1_hmac_sha256_t *hash, const unsigned char *key, size_t size);
-static void secp256k1_hmac_sha256_write(secp256k1_hmac_sha256_t *hash, const unsigned char *data, size_t size);
-static void secp256k1_hmac_sha256_finalize(secp256k1_hmac_sha256_t *hash, unsigned char *out32);
+static void secp256k1_hmac_sha256_initialize(secp256k1_hmac_sha256 *hash, const unsigned char *key, size_t size);
+static void secp256k1_hmac_sha256_write(secp256k1_hmac_sha256 *hash, const unsigned char *data, size_t size);
+static void secp256k1_hmac_sha256_finalize(secp256k1_hmac_sha256 *hash, unsigned char *out32);
 
 typedef struct {
     unsigned char v[32];
     unsigned char k[32];
     int retry;
-} secp256k1_rfc6979_hmac_sha256_t;
+} secp256k1_rfc6979_hmac_sha256;
 
-static void secp256k1_rfc6979_hmac_sha256_initialize(secp256k1_rfc6979_hmac_sha256_t *rng, const unsigned char *key, size_t keylen);
-static void secp256k1_rfc6979_hmac_sha256_generate(secp256k1_rfc6979_hmac_sha256_t *rng, unsigned char *out, size_t outlen);
-static void secp256k1_rfc6979_hmac_sha256_finalize(secp256k1_rfc6979_hmac_sha256_t *rng);
+static void secp256k1_rfc6979_hmac_sha256_initialize(secp256k1_rfc6979_hmac_sha256 *rng, const unsigned char *key, size_t keylen);
+static void secp256k1_rfc6979_hmac_sha256_generate(secp256k1_rfc6979_hmac_sha256 *rng, unsigned char *out, size_t outlen);
+static void secp256k1_rfc6979_hmac_sha256_finalize(secp256k1_rfc6979_hmac_sha256 *rng);
 
-#endif
+#endif /* SECP256K1_HASH_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/hash_impl.h b/crypto/secp256k1/libsecp256k1/src/hash_impl.h
index b47e65f83..782f97216 100644
--- a/crypto/secp256k1/libsecp256k1/src/hash_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/hash_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_HASH_IMPL_H_
-#define _SECP256K1_HASH_IMPL_H_
+#ifndef SECP256K1_HASH_IMPL_H
+#define SECP256K1_HASH_IMPL_H
 
 #include "hash.h"
 
@@ -33,7 +33,7 @@
 #define BE32(p) ((((p) & 0xFF) << 24) | (((p) & 0xFF00) << 8) | (((p) & 0xFF0000) >> 8) | (((p) & 0xFF000000) >> 24))
 #endif
 
-static void secp256k1_sha256_initialize(secp256k1_sha256_t *hash) {
+static void secp256k1_sha256_initialize(secp256k1_sha256 *hash) {
     hash->s[0] = 0x6a09e667ul;
     hash->s[1] = 0xbb67ae85ul;
     hash->s[2] = 0x3c6ef372ul;
@@ -128,14 +128,16 @@ static void secp256k1_sha256_transform(uint32_t* s, const uint32_t* chunk) {
     s[7] += h;
 }
 
-static void secp256k1_sha256_write(secp256k1_sha256_t *hash, const unsigned char *data, size_t len) {
+static void secp256k1_sha256_write(secp256k1_sha256 *hash, const unsigned char *data, size_t len) {
     size_t bufsize = hash->bytes & 0x3F;
     hash->bytes += len;
-    while (bufsize + len >= 64) {
+    VERIFY_CHECK(hash->bytes >= len);
+    while (len >= 64 - bufsize) {
         /* Fill the buffer, and process it. */
-        memcpy(((unsigned char*)hash->buf) + bufsize, data, 64 - bufsize);
-        data += 64 - bufsize;
-        len -= 64 - bufsize;
+        size_t chunk_len = 64 - bufsize;
+        memcpy(((unsigned char*)hash->buf) + bufsize, data, chunk_len);
+        data += chunk_len;
+        len -= chunk_len;
         secp256k1_sha256_transform(hash->s, hash->buf);
         bufsize = 0;
     }
@@ -145,7 +147,7 @@ static void secp256k1_sha256_write(secp256k1_sha256_t *hash, const unsigned char
     }
 }
 
-static void secp256k1_sha256_finalize(secp256k1_sha256_t *hash, unsigned char *out32) {
+static void secp256k1_sha256_finalize(secp256k1_sha256 *hash, unsigned char *out32) {
     static const unsigned char pad[64] = {0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
     uint32_t sizedesc[2];
     uint32_t out[8];
@@ -161,14 +163,14 @@ static void secp256k1_sha256_finalize(secp256k1_sha256_t *hash, unsigned char *o
     memcpy(out32, (const unsigned char*)out, 32);
 }
 
-static void secp256k1_hmac_sha256_initialize(secp256k1_hmac_sha256_t *hash, const unsigned char *key, size_t keylen) {
-    int n;
+static void secp256k1_hmac_sha256_initialize(secp256k1_hmac_sha256 *hash, const unsigned char *key, size_t keylen) {
+    size_t n;
     unsigned char rkey[64];
-    if (keylen <= 64) {
+    if (keylen <= sizeof(rkey)) {
         memcpy(rkey, key, keylen);
-        memset(rkey + keylen, 0, 64 - keylen);
+        memset(rkey + keylen, 0, sizeof(rkey) - keylen);
     } else {
-        secp256k1_sha256_t sha256;
+        secp256k1_sha256 sha256;
         secp256k1_sha256_initialize(&sha256);
         secp256k1_sha256_write(&sha256, key, keylen);
         secp256k1_sha256_finalize(&sha256, rkey);
@@ -176,24 +178,24 @@ static void secp256k1_hmac_sha256_initialize(secp256k1_hmac_sha256_t *hash, cons
     }
 
     secp256k1_sha256_initialize(&hash->outer);
-    for (n = 0; n < 64; n++) {
+    for (n = 0; n < sizeof(rkey); n++) {
         rkey[n] ^= 0x5c;
     }
-    secp256k1_sha256_write(&hash->outer, rkey, 64);
+    secp256k1_sha256_write(&hash->outer, rkey, sizeof(rkey));
 
     secp256k1_sha256_initialize(&hash->inner);
-    for (n = 0; n < 64; n++) {
+    for (n = 0; n < sizeof(rkey); n++) {
         rkey[n] ^= 0x5c ^ 0x36;
     }
-    secp256k1_sha256_write(&hash->inner, rkey, 64);
-    memset(rkey, 0, 64);
+    secp256k1_sha256_write(&hash->inner, rkey, sizeof(rkey));
+    memset(rkey, 0, sizeof(rkey));
 }
 
-static void secp256k1_hmac_sha256_write(secp256k1_hmac_sha256_t *hash, const unsigned char *data, size_t size) {
+static void secp256k1_hmac_sha256_write(secp256k1_hmac_sha256 *hash, const unsigned char *data, size_t size) {
     secp256k1_sha256_write(&hash->inner, data, size);
 }
 
-static void secp256k1_hmac_sha256_finalize(secp256k1_hmac_sha256_t *hash, unsigned char *out32) {
+static void secp256k1_hmac_sha256_finalize(secp256k1_hmac_sha256 *hash, unsigned char *out32) {
     unsigned char temp[32];
     secp256k1_sha256_finalize(&hash->inner, temp);
     secp256k1_sha256_write(&hash->outer, temp, 32);
@@ -202,8 +204,8 @@ static void secp256k1_hmac_sha256_finalize(secp256k1_hmac_sha256_t *hash, unsign
 }
 
 
-static void secp256k1_rfc6979_hmac_sha256_initialize(secp256k1_rfc6979_hmac_sha256_t *rng, const unsigned char *key, size_t keylen) {
-    secp256k1_hmac_sha256_t hmac;
+static void secp256k1_rfc6979_hmac_sha256_initialize(secp256k1_rfc6979_hmac_sha256 *rng, const unsigned char *key, size_t keylen) {
+    secp256k1_hmac_sha256 hmac;
     static const unsigned char zero[1] = {0x00};
     static const unsigned char one[1] = {0x01};
 
@@ -232,11 +234,11 @@ static void secp256k1_rfc6979_hmac_sha256_initialize(secp256k1_rfc6979_hmac_sha2
     rng->retry = 0;
 }
 
-static void secp256k1_rfc6979_hmac_sha256_generate(secp256k1_rfc6979_hmac_sha256_t *rng, unsigned char *out, size_t outlen) {
+static void secp256k1_rfc6979_hmac_sha256_generate(secp256k1_rfc6979_hmac_sha256 *rng, unsigned char *out, size_t outlen) {
     /* RFC6979 3.2.h. */
     static const unsigned char zero[1] = {0x00};
     if (rng->retry) {
-        secp256k1_hmac_sha256_t hmac;
+        secp256k1_hmac_sha256 hmac;
         secp256k1_hmac_sha256_initialize(&hmac, rng->k, 32);
         secp256k1_hmac_sha256_write(&hmac, rng->v, 32);
         secp256k1_hmac_sha256_write(&hmac, zero, 1);
@@ -247,7 +249,7 @@ static void secp256k1_rfc6979_hmac_sha256_generate(secp256k1_rfc6979_hmac_sha256
     }
 
     while (outlen > 0) {
-        secp256k1_hmac_sha256_t hmac;
+        secp256k1_hmac_sha256 hmac;
         int now = outlen;
         secp256k1_hmac_sha256_initialize(&hmac, rng->k, 32);
         secp256k1_hmac_sha256_write(&hmac, rng->v, 32);
@@ -263,7 +265,7 @@ static void secp256k1_rfc6979_hmac_sha256_generate(secp256k1_rfc6979_hmac_sha256
     rng->retry = 1;
 }
 
-static void secp256k1_rfc6979_hmac_sha256_finalize(secp256k1_rfc6979_hmac_sha256_t *rng) {
+static void secp256k1_rfc6979_hmac_sha256_finalize(secp256k1_rfc6979_hmac_sha256 *rng) {
     memset(rng->k, 0, 32);
     memset(rng->v, 0, 32);
     rng->retry = 0;
@@ -278,4 +280,4 @@ static void secp256k1_rfc6979_hmac_sha256_finalize(secp256k1_rfc6979_hmac_sha256
 #undef Maj
 #undef Ch
 
-#endif
+#endif /* SECP256K1_HASH_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1.java b/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1.java
deleted file mode 100644
index 1c67802fb..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1.java
+++ /dev/null
@@ -1,446 +0,0 @@
-/*
- * Copyright 2013 Google Inc.
- * Copyright 2014-2016 the libsecp256k1 contributors
- *
- * Licensed under the Apache License, Version 2.0 (the "License");
- * you may not use this file except in compliance with the License.
- * You may obtain a copy of the License at
- *
- *    http://www.apache.org/licenses/LICENSE-2.0
- *
- * Unless required by applicable law or agreed to in writing, software
- * distributed under the License is distributed on an "AS IS" BASIS,
- * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
- * See the License for the specific language governing permissions and
- * limitations under the License.
- */
-
-package org.bitcoin;
-
-import java.nio.ByteBuffer;
-import java.nio.ByteOrder;
-
-import java.math.BigInteger;
-import com.google.common.base.Preconditions;
-import java.util.concurrent.locks.Lock;
-import java.util.concurrent.locks.ReentrantReadWriteLock;
-import static org.bitcoin.NativeSecp256k1Util.*;
-
-/**
- * <p>This class holds native methods to handle ECDSA verification.</p>
- *
- * <p>You can find an example library that can be used for this at https://github.com/bitcoin/secp256k1</p>
- *
- * <p>To build secp256k1 for use with bitcoinj, run
- * `./configure --enable-jni --enable-experimental --enable-module-ecdh`
- * and `make` then copy `.libs/libsecp256k1.so` to your system library path
- * or point the JVM to the folder containing it with -Djava.library.path
- * </p>
- */
-public class NativeSecp256k1 {
-
-    private static final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock();
-    private static final Lock r = rwl.readLock();
-    private static final Lock w = rwl.writeLock();
-    private static ThreadLocal<ByteBuffer> nativeECDSABuffer = new ThreadLocal<ByteBuffer>();
-    /**
-     * Verifies the given secp256k1 signature in native code.
-     * Calling when enabled == false is undefined (probably library not loaded)
-     *
-     * @param data The data which was signed, must be exactly 32 bytes
-     * @param signature The signature
-     * @param pub The public key which did the signing
-     */
-    public static boolean verify(byte[] data, byte[] signature, byte[] pub) throws AssertFailException{
-        Preconditions.checkArgument(data.length == 32 && signature.length <= 520 && pub.length <= 520);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < 520) {
-            byteBuff = ByteBuffer.allocateDirect(520);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(data);
-        byteBuff.put(signature);
-        byteBuff.put(pub);
-
-        byte[][] retByteArray;
-
-        r.lock();
-        try {
-          return secp256k1_ecdsa_verify(byteBuff, Secp256k1Context.getContext(), signature.length, pub.length) == 1;
-        } finally {
-          r.unlock();
-        }
-    }
-
-    /**
-     * libsecp256k1 Create an ECDSA signature.
-     *
-     * @param data Message hash, 32 bytes
-     * @param key Secret key, 32 bytes
-     *
-     * Return values
-     * @param sig byte array of signature
-     */
-    public static byte[] sign(byte[] data, byte[] sec) throws AssertFailException{
-        Preconditions.checkArgument(data.length == 32 && sec.length <= 32);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < 32 + 32) {
-            byteBuff = ByteBuffer.allocateDirect(32 + 32);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(data);
-        byteBuff.put(sec);
-
-        byte[][] retByteArray;
-
-        r.lock();
-        try {
-          retByteArray = secp256k1_ecdsa_sign(byteBuff, Secp256k1Context.getContext());
-        } finally {
-          r.unlock();
-        }
-
-        byte[] sigArr = retByteArray[0];
-        int sigLen = new BigInteger(new byte[] { retByteArray[1][0] }).intValue();
-        int retVal = new BigInteger(new byte[] { retByteArray[1][1] }).intValue();
-
-        assertEquals(sigArr.length, sigLen, "Got bad signature length.");
-
-        return retVal == 0 ? new byte[0] : sigArr;
-    }
-
-    /**
-     * libsecp256k1 Seckey Verify - returns 1 if valid, 0 if invalid
-     *
-     * @param seckey ECDSA Secret key, 32 bytes
-     */
-    public static boolean secKeyVerify(byte[] seckey) {
-        Preconditions.checkArgument(seckey.length == 32);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < seckey.length) {
-            byteBuff = ByteBuffer.allocateDirect(seckey.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(seckey);
-
-        r.lock();
-        try {
-          return secp256k1_ec_seckey_verify(byteBuff,Secp256k1Context.getContext()) == 1;
-        } finally {
-          r.unlock();
-        }
-    }
-
-
-    /**
-     * libsecp256k1 Compute Pubkey - computes public key from secret key
-     *
-     * @param seckey ECDSA Secret key, 32 bytes
-     *
-     * Return values
-     * @param pubkey ECDSA Public key, 33 or 65 bytes
-     */
-    //TODO add a 'compressed' arg
-    public static byte[] computePubkey(byte[] seckey) throws AssertFailException{
-        Preconditions.checkArgument(seckey.length == 32);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < seckey.length) {
-            byteBuff = ByteBuffer.allocateDirect(seckey.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(seckey);
-
-        byte[][] retByteArray;
-
-        r.lock();
-        try {
-          retByteArray = secp256k1_ec_pubkey_create(byteBuff, Secp256k1Context.getContext());
-        } finally {
-          r.unlock();
-        }
-
-        byte[] pubArr = retByteArray[0];
-        int pubLen = new BigInteger(new byte[] { retByteArray[1][0] }).intValue();
-        int retVal = new BigInteger(new byte[] { retByteArray[1][1] }).intValue();
-
-        assertEquals(pubArr.length, pubLen, "Got bad pubkey length.");
-
-        return retVal == 0 ? new byte[0]: pubArr;
-    }
-
-    /**
-     * libsecp256k1 Cleanup - This destroys the secp256k1 context object
-     * This should be called at the end of the program for proper cleanup of the context.
-     */
-    public static synchronized void cleanup() {
-        w.lock();
-        try {
-          secp256k1_destroy_context(Secp256k1Context.getContext());
-        } finally {
-          w.unlock();
-        }
-    }
-
-    public static long cloneContext() {
-       r.lock();
-       try {
-        return secp256k1_ctx_clone(Secp256k1Context.getContext());
-       } finally { r.unlock(); }
-    }
-
-    /**
-     * libsecp256k1 PrivKey Tweak-Mul - Tweak privkey by multiplying to it
-     *
-     * @param tweak some bytes to tweak with
-     * @param seckey 32-byte seckey
-     */
-    public static byte[] privKeyTweakMul(byte[] privkey, byte[] tweak) throws AssertFailException{
-        Preconditions.checkArgument(privkey.length == 32);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < privkey.length + tweak.length) {
-            byteBuff = ByteBuffer.allocateDirect(privkey.length + tweak.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(privkey);
-        byteBuff.put(tweak);
-
-        byte[][] retByteArray;
-        r.lock();
-        try {
-          retByteArray = secp256k1_privkey_tweak_mul(byteBuff,Secp256k1Context.getContext());
-        } finally {
-          r.unlock();
-        }
-
-        byte[] privArr = retByteArray[0];
-
-        int privLen = (byte) new BigInteger(new byte[] { retByteArray[1][0] }).intValue() & 0xFF;
-        int retVal = new BigInteger(new byte[] { retByteArray[1][1] }).intValue();
-
-        assertEquals(privArr.length, privLen, "Got bad pubkey length.");
-
-        assertEquals(retVal, 1, "Failed return value check.");
-
-        return privArr;
-    }
-
-    /**
-     * libsecp256k1 PrivKey Tweak-Add - Tweak privkey by adding to it
-     *
-     * @param tweak some bytes to tweak with
-     * @param seckey 32-byte seckey
-     */
-    public static byte[] privKeyTweakAdd(byte[] privkey, byte[] tweak) throws AssertFailException{
-        Preconditions.checkArgument(privkey.length == 32);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < privkey.length + tweak.length) {
-            byteBuff = ByteBuffer.allocateDirect(privkey.length + tweak.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(privkey);
-        byteBuff.put(tweak);
-
-        byte[][] retByteArray;
-        r.lock();
-        try {
-          retByteArray = secp256k1_privkey_tweak_add(byteBuff,Secp256k1Context.getContext());
-        } finally {
-          r.unlock();
-        }
-
-        byte[] privArr = retByteArray[0];
-
-        int privLen = (byte) new BigInteger(new byte[] { retByteArray[1][0] }).intValue() & 0xFF;
-        int retVal = new BigInteger(new byte[] { retByteArray[1][1] }).intValue();
-
-        assertEquals(privArr.length, privLen, "Got bad pubkey length.");
-
-        assertEquals(retVal, 1, "Failed return value check.");
-
-        return privArr;
-    }
-
-    /**
-     * libsecp256k1 PubKey Tweak-Add - Tweak pubkey by adding to it
-     *
-     * @param tweak some bytes to tweak with
-     * @param pubkey 32-byte seckey
-     */
-    public static byte[] pubKeyTweakAdd(byte[] pubkey, byte[] tweak) throws AssertFailException{
-        Preconditions.checkArgument(pubkey.length == 33 || pubkey.length == 65);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < pubkey.length + tweak.length) {
-            byteBuff = ByteBuffer.allocateDirect(pubkey.length + tweak.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(pubkey);
-        byteBuff.put(tweak);
-
-        byte[][] retByteArray;
-        r.lock();
-        try {
-          retByteArray = secp256k1_pubkey_tweak_add(byteBuff,Secp256k1Context.getContext(), pubkey.length);
-        } finally {
-          r.unlock();
-        }
-
-        byte[] pubArr = retByteArray[0];
-
-        int pubLen = (byte) new BigInteger(new byte[] { retByteArray[1][0] }).intValue() & 0xFF;
-        int retVal = new BigInteger(new byte[] { retByteArray[1][1] }).intValue();
-
-        assertEquals(pubArr.length, pubLen, "Got bad pubkey length.");
-
-        assertEquals(retVal, 1, "Failed return value check.");
-
-        return pubArr;
-    }
-
-    /**
-     * libsecp256k1 PubKey Tweak-Mul - Tweak pubkey by multiplying to it
-     *
-     * @param tweak some bytes to tweak with
-     * @param pubkey 32-byte seckey
-     */
-    public static byte[] pubKeyTweakMul(byte[] pubkey, byte[] tweak) throws AssertFailException{
-        Preconditions.checkArgument(pubkey.length == 33 || pubkey.length == 65);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < pubkey.length + tweak.length) {
-            byteBuff = ByteBuffer.allocateDirect(pubkey.length + tweak.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(pubkey);
-        byteBuff.put(tweak);
-
-        byte[][] retByteArray;
-        r.lock();
-        try {
-          retByteArray = secp256k1_pubkey_tweak_mul(byteBuff,Secp256k1Context.getContext(), pubkey.length);
-        } finally {
-          r.unlock();
-        }
-
-        byte[] pubArr = retByteArray[0];
-
-        int pubLen = (byte) new BigInteger(new byte[] { retByteArray[1][0] }).intValue() & 0xFF;
-        int retVal = new BigInteger(new byte[] { retByteArray[1][1] }).intValue();
-
-        assertEquals(pubArr.length, pubLen, "Got bad pubkey length.");
-
-        assertEquals(retVal, 1, "Failed return value check.");
-
-        return pubArr;
-    }
-
-    /**
-     * libsecp256k1 create ECDH secret - constant time ECDH calculation
-     *
-     * @param seckey byte array of secret key used in exponentiaion
-     * @param pubkey byte array of public key used in exponentiaion
-     */
-    public static byte[] createECDHSecret(byte[] seckey, byte[] pubkey) throws AssertFailException{
-        Preconditions.checkArgument(seckey.length <= 32 && pubkey.length <= 65);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < 32 + pubkey.length) {
-            byteBuff = ByteBuffer.allocateDirect(32 + pubkey.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(seckey);
-        byteBuff.put(pubkey);
-
-        byte[][] retByteArray;
-        r.lock();
-        try {
-          retByteArray = secp256k1_ecdh(byteBuff, Secp256k1Context.getContext(), pubkey.length);
-        } finally {
-          r.unlock();
-        }
-
-        byte[] resArr = retByteArray[0];
-        int retVal = new BigInteger(new byte[] { retByteArray[1][0] }).intValue();
-
-        assertEquals(resArr.length, 32, "Got bad result length.");
-        assertEquals(retVal, 1, "Failed return value check.");
-
-        return resArr;
-    }
-
-    /**
-     * libsecp256k1 randomize - updates the context randomization
-     *
-     * @param seed 32-byte random seed
-     */
-    public static synchronized boolean randomize(byte[] seed) throws AssertFailException{
-        Preconditions.checkArgument(seed.length == 32 || seed == null);
-
-        ByteBuffer byteBuff = nativeECDSABuffer.get();
-        if (byteBuff == null || byteBuff.capacity() < seed.length) {
-            byteBuff = ByteBuffer.allocateDirect(seed.length);
-            byteBuff.order(ByteOrder.nativeOrder());
-            nativeECDSABuffer.set(byteBuff);
-        }
-        byteBuff.rewind();
-        byteBuff.put(seed);
-
-        w.lock();
-        try {
-          return secp256k1_context_randomize(byteBuff, Secp256k1Context.getContext()) == 1;
-        } finally {
-          w.unlock();
-        }
-    }
-
-    private static native long secp256k1_ctx_clone(long context);
-
-    private static native int secp256k1_context_randomize(ByteBuffer byteBuff, long context);
-
-    private static native byte[][] secp256k1_privkey_tweak_add(ByteBuffer byteBuff, long context);
-
-    private static native byte[][] secp256k1_privkey_tweak_mul(ByteBuffer byteBuff, long context);
-
-    private static native byte[][] secp256k1_pubkey_tweak_add(ByteBuffer byteBuff, long context, int pubLen);
-
-    private static native byte[][] secp256k1_pubkey_tweak_mul(ByteBuffer byteBuff, long context, int pubLen);
-
-    private static native void secp256k1_destroy_context(long context);
-
-    private static native int secp256k1_ecdsa_verify(ByteBuffer byteBuff, long context, int sigLen, int pubLen);
-
-    private static native byte[][] secp256k1_ecdsa_sign(ByteBuffer byteBuff, long context);
-
-    private static native int secp256k1_ec_seckey_verify(ByteBuffer byteBuff, long context);
-
-    private static native byte[][] secp256k1_ec_pubkey_create(ByteBuffer byteBuff, long context);
-
-    private static native byte[][] secp256k1_ec_pubkey_parse(ByteBuffer byteBuff, long context, int inputLen);
-
-    private static native byte[][] secp256k1_ecdh(ByteBuffer byteBuff, long context, int inputLen);
-
-}
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1Test.java b/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1Test.java
deleted file mode 100644
index c00d08899..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1Test.java
+++ /dev/null
@@ -1,226 +0,0 @@
-package org.bitcoin;
-
-import com.google.common.io.BaseEncoding;
-import java.util.Arrays;
-import java.math.BigInteger;
-import javax.xml.bind.DatatypeConverter;
-import static org.bitcoin.NativeSecp256k1Util.*;
-
-/**
- * This class holds test cases defined for testing this library.
- */
-public class NativeSecp256k1Test {
-
-    //TODO improve comments/add more tests
-    /**
-      * This tests verify() for a valid signature
-      */
-    public static void testVerifyPos() throws AssertFailException{
-        boolean result = false;
-        byte[] data = BaseEncoding.base16().lowerCase().decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".toLowerCase()); //sha256hash of "testing"
-        byte[] sig = BaseEncoding.base16().lowerCase().decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589".toLowerCase());
-        byte[] pub = BaseEncoding.base16().lowerCase().decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40".toLowerCase());
-
-        result = NativeSecp256k1.verify( data, sig, pub);
-        assertEquals( result, true , "testVerifyPos");
-    }
-
-    /**
-      * This tests verify() for a non-valid signature
-      */
-    public static void testVerifyNeg() throws AssertFailException{
-        boolean result = false;
-        byte[] data = BaseEncoding.base16().lowerCase().decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A91".toLowerCase()); //sha256hash of "testing"
-        byte[] sig = BaseEncoding.base16().lowerCase().decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589".toLowerCase());
-        byte[] pub = BaseEncoding.base16().lowerCase().decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40".toLowerCase());
-
-        result = NativeSecp256k1.verify( data, sig, pub);
-        //System.out.println(" TEST " + new BigInteger(1, resultbytes).toString(16));
-        assertEquals( result, false , "testVerifyNeg");
-    }
-
-    /**
-      * This tests secret key verify() for a valid secretkey
-      */
-    public static void testSecKeyVerifyPos() throws AssertFailException{
-        boolean result = false;
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".toLowerCase());
-
-        result = NativeSecp256k1.secKeyVerify( sec );
-        //System.out.println(" TEST " + new BigInteger(1, resultbytes).toString(16));
-        assertEquals( result, true , "testSecKeyVerifyPos");
-    }
-
-    /**
-      * This tests secret key verify() for a invalid secretkey
-      */
-    public static void testSecKeyVerifyNeg() throws AssertFailException{
-        boolean result = false;
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".toLowerCase());
-
-        result = NativeSecp256k1.secKeyVerify( sec );
-        //System.out.println(" TEST " + new BigInteger(1, resultbytes).toString(16));
-        assertEquals( result, false , "testSecKeyVerifyNeg");
-    }
-
-    /**
-      * This tests public key create() for a valid secretkey
-      */
-    public static void testPubKeyCreatePos() throws AssertFailException{
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".toLowerCase());
-
-        byte[] resultArr = NativeSecp256k1.computePubkey( sec);
-        String pubkeyString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( pubkeyString , "04C591A8FF19AC9C4E4E5793673B83123437E975285E7B442F4EE2654DFFCA5E2D2103ED494718C697AC9AEBCFD19612E224DB46661011863ED2FC54E71861E2A6" , "testPubKeyCreatePos");
-    }
-
-    /**
-      * This tests public key create() for a invalid secretkey
-      */
-    public static void testPubKeyCreateNeg() throws AssertFailException{
-       byte[] sec = BaseEncoding.base16().lowerCase().decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".toLowerCase());
-
-       byte[] resultArr = NativeSecp256k1.computePubkey( sec);
-       String pubkeyString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-       assertEquals( pubkeyString, "" , "testPubKeyCreateNeg");
-    }
-
-    /**
-      * This tests sign() for a valid secretkey
-      */
-    public static void testSignPos() throws AssertFailException{
-
-        byte[] data = BaseEncoding.base16().lowerCase().decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".toLowerCase()); //sha256hash of "testing"
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".toLowerCase());
-
-        byte[] resultArr = NativeSecp256k1.sign(data, sec);
-        String sigString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( sigString, "30440220182A108E1448DC8F1FB467D06A0F3BB8EA0533584CB954EF8DA112F1D60E39A202201C66F36DA211C087F3AF88B50EDF4F9BDAA6CF5FD6817E74DCA34DB12390C6E9" , "testSignPos");
-    }
-
-    /**
-      * This tests sign() for a invalid secretkey
-      */
-    public static void testSignNeg() throws AssertFailException{
-        byte[] data = BaseEncoding.base16().lowerCase().decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".toLowerCase()); //sha256hash of "testing"
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".toLowerCase());
-
-        byte[] resultArr = NativeSecp256k1.sign(data, sec);
-        String sigString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( sigString, "" , "testSignNeg");
-    }
-
-    /**
-      * This tests private key tweak-add
-      */
-    public static void testPrivKeyTweakAdd_1() throws AssertFailException {
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".toLowerCase());
-        byte[] data = BaseEncoding.base16().lowerCase().decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".toLowerCase()); //sha256hash of "tweak"
-
-        byte[] resultArr = NativeSecp256k1.privKeyTweakAdd( sec , data );
-        String sigString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( sigString , "A168571E189E6F9A7E2D657A4B53AE99B909F7E712D1C23CED28093CD57C88F3" , "testPrivKeyAdd_1");
-    }
-
-    /**
-      * This tests private key tweak-mul
-      */
-    public static void testPrivKeyTweakMul_1() throws AssertFailException {
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".toLowerCase());
-        byte[] data = BaseEncoding.base16().lowerCase().decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".toLowerCase()); //sha256hash of "tweak"
-
-        byte[] resultArr = NativeSecp256k1.privKeyTweakMul( sec , data );
-        String sigString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( sigString , "97F8184235F101550F3C71C927507651BD3F1CDB4A5A33B8986ACF0DEE20FFFC" , "testPrivKeyMul_1");
-    }
-
-    /**
-      * This tests private key tweak-add uncompressed
-      */
-    public static void testPrivKeyTweakAdd_2() throws AssertFailException {
-        byte[] pub = BaseEncoding.base16().lowerCase().decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40".toLowerCase());
-        byte[] data = BaseEncoding.base16().lowerCase().decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".toLowerCase()); //sha256hash of "tweak"
-
-        byte[] resultArr = NativeSecp256k1.pubKeyTweakAdd( pub , data );
-        String sigString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( sigString , "0411C6790F4B663CCE607BAAE08C43557EDC1A4D11D88DFCB3D841D0C6A941AF525A268E2A863C148555C48FB5FBA368E88718A46E205FABC3DBA2CCFFAB0796EF" , "testPrivKeyAdd_2");
-    }
-
-    /**
-      * This tests private key tweak-mul uncompressed
-      */
-    public static void testPrivKeyTweakMul_2() throws AssertFailException {
-        byte[] pub = BaseEncoding.base16().lowerCase().decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40".toLowerCase());
-        byte[] data = BaseEncoding.base16().lowerCase().decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".toLowerCase()); //sha256hash of "tweak"
-
-        byte[] resultArr = NativeSecp256k1.pubKeyTweakMul( pub , data );
-        String sigString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( sigString , "04E0FE6FE55EBCA626B98A807F6CAF654139E14E5E3698F01A9A658E21DC1D2791EC060D4F412A794D5370F672BC94B722640B5F76914151CFCA6E712CA48CC589" , "testPrivKeyMul_2");
-    }
-
-    /**
-      * This tests seed randomization
-      */
-    public static void testRandomize() throws AssertFailException {
-        byte[] seed = BaseEncoding.base16().lowerCase().decode("A441B15FE9A3CF56661190A0B93B9DEC7D04127288CC87250967CF3B52894D11".toLowerCase()); //sha256hash of "random"
-        boolean result = NativeSecp256k1.randomize(seed);
-        assertEquals( result, true, "testRandomize");
-    }
-
-    public static void testCreateECDHSecret() throws AssertFailException{
-
-        byte[] sec = BaseEncoding.base16().lowerCase().decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".toLowerCase());
-        byte[] pub = BaseEncoding.base16().lowerCase().decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40".toLowerCase());
-
-        byte[] resultArr = NativeSecp256k1.createECDHSecret(sec, pub);
-        String ecdhString = javax.xml.bind.DatatypeConverter.printHexBinary(resultArr);
-        assertEquals( ecdhString, "2A2A67007A926E6594AF3EB564FC74005B37A9C8AEF2033C4552051B5C87F043" , "testCreateECDHSecret");
-    }
-
-    public static void main(String[] args) throws AssertFailException{
-
-
-        System.out.println("\n libsecp256k1 enabled: " + Secp256k1Context.isEnabled() + "\n");
-
-        assertEquals( Secp256k1Context.isEnabled(), true, "isEnabled" );
-
-        //Test verify() success/fail
-        testVerifyPos();
-        testVerifyNeg();
-
-        //Test secKeyVerify() success/fail
-        testSecKeyVerifyPos();
-        testSecKeyVerifyNeg();
-
-        //Test computePubkey() success/fail
-        testPubKeyCreatePos();
-        testPubKeyCreateNeg();
-
-        //Test sign() success/fail
-        testSignPos();
-        testSignNeg();
-
-        //Test privKeyTweakAdd() 1
-        testPrivKeyTweakAdd_1();
-
-        //Test privKeyTweakMul() 2
-        testPrivKeyTweakMul_1();
-
-        //Test privKeyTweakAdd() 3
-        testPrivKeyTweakAdd_2();
-
-        //Test privKeyTweakMul() 4
-        testPrivKeyTweakMul_2();
-
-        //Test randomize()
-        testRandomize();
-
-        //Test ECDH
-        testCreateECDHSecret();
-
-        NativeSecp256k1.cleanup();
-
-        System.out.println(" All tests passed." );
-
-    }
-}
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1Util.java b/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1Util.java
deleted file mode 100644
index 04732ba04..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/NativeSecp256k1Util.java
+++ /dev/null
@@ -1,45 +0,0 @@
-/*
- * Copyright 2014-2016 the libsecp256k1 contributors
- *
- * Licensed under the Apache License, Version 2.0 (the "License");
- * you may not use this file except in compliance with the License.
- * You may obtain a copy of the License at
- *
- *    http://www.apache.org/licenses/LICENSE-2.0
- *
- * Unless required by applicable law or agreed to in writing, software
- * distributed under the License is distributed on an "AS IS" BASIS,
- * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
- * See the License for the specific language governing permissions and
- * limitations under the License.
- */
-
-package org.bitcoin;
-
-public class NativeSecp256k1Util{
-
-    public static void assertEquals( int val, int val2, String message ) throws AssertFailException{
-      if( val != val2 )
-        throw new AssertFailException("FAIL: " + message);
-    }
-
-    public static void assertEquals( boolean val, boolean val2, String message ) throws AssertFailException{
-      if( val != val2 )
-        throw new AssertFailException("FAIL: " + message);
-      else
-        System.out.println("PASS: " + message);
-    }
-
-    public static void assertEquals( String val, String val2, String message ) throws AssertFailException{
-      if( !val.equals(val2) )
-        throw new AssertFailException("FAIL: " + message);
-      else
-        System.out.println("PASS: " + message);
-    }
-
-    public static class AssertFailException extends Exception {
-      public AssertFailException(String message) {
-        super( message );
-      }
-    }
-}
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/Secp256k1Context.java b/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/Secp256k1Context.java
deleted file mode 100644
index 216c986a8..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org/bitcoin/Secp256k1Context.java
+++ /dev/null
@@ -1,51 +0,0 @@
-/*
- * Copyright 2014-2016 the libsecp256k1 contributors
- *
- * Licensed under the Apache License, Version 2.0 (the "License");
- * you may not use this file except in compliance with the License.
- * You may obtain a copy of the License at
- *
- *    http://www.apache.org/licenses/LICENSE-2.0
- *
- * Unless required by applicable law or agreed to in writing, software
- * distributed under the License is distributed on an "AS IS" BASIS,
- * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
- * See the License for the specific language governing permissions and
- * limitations under the License.
- */
-
-package org.bitcoin;
-
-/**
- * This class holds the context reference used in native methods 
- * to handle ECDSA operations.
- */
-public class Secp256k1Context {
-  private static final boolean enabled; //true if the library is loaded
-  private static final long context; //ref to pointer to context obj
-
-  static { //static initializer
-      boolean isEnabled = true;
-      long contextRef = -1;
-      try {
-          System.loadLibrary("secp256k1");
-          contextRef = secp256k1_init_context();
-      } catch (UnsatisfiedLinkError e) {
-          System.out.println("UnsatisfiedLinkError: " + e.toString());
-          isEnabled = false;
-      }
-      enabled = isEnabled;
-      context = contextRef;
-  }
-
-  public static boolean isEnabled() {
-     return enabled;
-  }
-
-  public static long getContext() {
-     if(!enabled) return -1; //sanity check
-     return context;
-  }
-
-  private static native long secp256k1_init_context();
-}
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_NativeSecp256k1.c b/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_NativeSecp256k1.c
deleted file mode 100644
index bcef7b32c..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_NativeSecp256k1.c
+++ /dev/null
@@ -1,377 +0,0 @@
-#include <stdlib.h>
-#include <stdint.h>
-#include <string.h>
-#include "org_bitcoin_NativeSecp256k1.h"
-#include "include/secp256k1.h"
-#include "include/secp256k1_ecdh.h"
-#include "include/secp256k1_recovery.h"
-
-
-SECP256K1_API jlong JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ctx_1clone
-  (JNIEnv* env, jclass classObject, jlong ctx_l)
-{
-  const secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-
-  jlong ctx_clone_l = (uintptr_t) secp256k1_context_clone(ctx);
-
-  (void)classObject;(void)env;
-
-  return ctx_clone_l;
-
-}
-
-SECP256K1_API jint JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1context_1randomize
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-
-  const unsigned char* seed = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-
-  (void)classObject;
-
-  return secp256k1_context_randomize(ctx, seed);
-
-}
-
-SECP256K1_API void JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1destroy_1context
-  (JNIEnv* env, jclass classObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-
-  secp256k1_context_destroy(ctx);
-
-  (void)classObject;(void)env;
-}
-
-SECP256K1_API jint JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdsa_1verify
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l, jint siglen, jint publen)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-
-  unsigned char* data = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  const unsigned char* sigdata = {  (unsigned char*) (data + 32) };
-  const unsigned char* pubdata = { (unsigned char*) (data + siglen + 32) };
-
-  secp256k1_ecdsa_signature sig;
-  secp256k1_pubkey pubkey;
-
-  int ret = secp256k1_ecdsa_signature_parse_der(ctx, &sig, sigdata, siglen);
-
-  if( ret ) {
-    ret = secp256k1_ec_pubkey_parse(ctx, &pubkey, pubdata, publen);
-
-    if( ret ) {
-      ret = secp256k1_ecdsa_verify(ctx, &sig, data, &pubkey);
-    }
-  }
-
-  (void)classObject;
-
-  return ret;
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdsa_1sign
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  unsigned char* data = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  unsigned char* secKey = (unsigned char*) (data + 32);
-
-  jobjectArray retArray;
-  jbyteArray sigArray, intsByteArray;
-  unsigned char intsarray[2];
-
-  secp256k1_ecdsa_signature sig[72];
-
-  int ret = secp256k1_ecdsa_sign(ctx, sig, data, secKey, NULL, NULL );
-
-  unsigned char outputSer[72];
-  size_t outputLen = 72;
-
-  if( ret ) {
-    int ret2 = secp256k1_ecdsa_signature_serialize_der(ctx,outputSer, &outputLen, sig ); (void)ret2;
-  }
-
-  intsarray[0] = outputLen;
-  intsarray[1] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  sigArray = (*env)->NewByteArray(env, outputLen);
-  (*env)->SetByteArrayRegion(env, sigArray, 0, outputLen, (jbyte*)outputSer);
-  (*env)->SetObjectArrayElement(env, retArray, 0, sigArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 2);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 2, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-}
-
-SECP256K1_API jint JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ec_1seckey_1verify
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  unsigned char* secKey = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-
-  (void)classObject;
-
-  return secp256k1_ec_seckey_verify(ctx, secKey);
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ec_1pubkey_1create
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  const unsigned char* secKey = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-
-  secp256k1_pubkey pubkey;
-
-  jobjectArray retArray;
-  jbyteArray pubkeyArray, intsByteArray;
-  unsigned char intsarray[2];
-
-  int ret = secp256k1_ec_pubkey_create(ctx, &pubkey, secKey);
-
-  unsigned char outputSer[65];
-  size_t outputLen = 65;
-
-  if( ret ) {
-    int ret2 = secp256k1_ec_pubkey_serialize(ctx,outputSer, &outputLen, &pubkey,SECP256K1_EC_UNCOMPRESSED );(void)ret2;
-  }
-
-  intsarray[0] = outputLen;
-  intsarray[1] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  pubkeyArray = (*env)->NewByteArray(env, outputLen);
-  (*env)->SetByteArrayRegion(env, pubkeyArray, 0, outputLen, (jbyte*)outputSer);
-  (*env)->SetObjectArrayElement(env, retArray, 0, pubkeyArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 2);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 2, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1privkey_1tweak_1add
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  unsigned char* privkey = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  const unsigned char* tweak = (unsigned char*) (privkey + 32);
-
-  jobjectArray retArray;
-  jbyteArray privArray, intsByteArray;
-  unsigned char intsarray[2];
-
-  int privkeylen = 32;
-
-  int ret = secp256k1_ec_privkey_tweak_add(ctx, privkey, tweak);
-
-  intsarray[0] = privkeylen;
-  intsarray[1] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  privArray = (*env)->NewByteArray(env, privkeylen);
-  (*env)->SetByteArrayRegion(env, privArray, 0, privkeylen, (jbyte*)privkey);
-  (*env)->SetObjectArrayElement(env, retArray, 0, privArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 2);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 2, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1privkey_1tweak_1mul
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  unsigned char* privkey = (unsigned char*) (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  const unsigned char* tweak = (unsigned char*) (privkey + 32);
-
-  jobjectArray retArray;
-  jbyteArray privArray, intsByteArray;
-  unsigned char intsarray[2];
-
-  int privkeylen = 32;
-
-  int ret = secp256k1_ec_privkey_tweak_mul(ctx, privkey, tweak);
-
-  intsarray[0] = privkeylen;
-  intsarray[1] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  privArray = (*env)->NewByteArray(env, privkeylen);
-  (*env)->SetByteArrayRegion(env, privArray, 0, privkeylen, (jbyte*)privkey);
-  (*env)->SetObjectArrayElement(env, retArray, 0, privArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 2);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 2, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1pubkey_1tweak_1add
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l, jint publen)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-/*  secp256k1_pubkey* pubkey = (secp256k1_pubkey*) (*env)->GetDirectBufferAddress(env, byteBufferObject);*/
-  unsigned char* pkey = (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  const unsigned char* tweak = (unsigned char*) (pkey + publen);
-
-  jobjectArray retArray;
-  jbyteArray pubArray, intsByteArray;
-  unsigned char intsarray[2];
-  unsigned char outputSer[65];
-  size_t outputLen = 65;
-
-  secp256k1_pubkey pubkey;
-  int ret = secp256k1_ec_pubkey_parse(ctx, &pubkey, pkey, publen);
-
-  if( ret ) {
-    ret = secp256k1_ec_pubkey_tweak_add(ctx, &pubkey, tweak);
-  }
-
-  if( ret ) {
-    int ret2 = secp256k1_ec_pubkey_serialize(ctx,outputSer, &outputLen, &pubkey,SECP256K1_EC_UNCOMPRESSED );(void)ret2;
-  }
-
-  intsarray[0] = outputLen;
-  intsarray[1] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  pubArray = (*env)->NewByteArray(env, outputLen);
-  (*env)->SetByteArrayRegion(env, pubArray, 0, outputLen, (jbyte*)outputSer);
-  (*env)->SetObjectArrayElement(env, retArray, 0, pubArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 2);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 2, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1pubkey_1tweak_1mul
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l, jint publen)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  unsigned char* pkey = (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  const unsigned char* tweak = (unsigned char*) (pkey + publen);
-
-  jobjectArray retArray;
-  jbyteArray pubArray, intsByteArray;
-  unsigned char intsarray[2];
-  unsigned char outputSer[65];
-  size_t outputLen = 65;
-
-  secp256k1_pubkey pubkey;
-  int ret = secp256k1_ec_pubkey_parse(ctx, &pubkey, pkey, publen);
-
-  if ( ret ) {
-    ret = secp256k1_ec_pubkey_tweak_mul(ctx, &pubkey, tweak);
-  }
-
-  if( ret ) {
-    int ret2 = secp256k1_ec_pubkey_serialize(ctx,outputSer, &outputLen, &pubkey,SECP256K1_EC_UNCOMPRESSED );(void)ret2;
-  }
-
-  intsarray[0] = outputLen;
-  intsarray[1] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  pubArray = (*env)->NewByteArray(env, outputLen);
-  (*env)->SetByteArrayRegion(env, pubArray, 0, outputLen, (jbyte*)outputSer);
-  (*env)->SetObjectArrayElement(env, retArray, 0, pubArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 2);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 2, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-}
-
-SECP256K1_API jlong JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdsa_1pubkey_1combine
-  (JNIEnv * env, jclass classObject, jobject byteBufferObject, jlong ctx_l, jint numkeys)
-{
-  (void)classObject;(void)env;(void)byteBufferObject;(void)ctx_l;(void)numkeys;
-
-  return 0;
-}
-
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdh
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l, jint publen)
-{
-  secp256k1_context *ctx = (secp256k1_context*)(uintptr_t)ctx_l;
-  const unsigned char* secdata = (*env)->GetDirectBufferAddress(env, byteBufferObject);
-  const unsigned char* pubdata = (const unsigned char*) (secdata + 32);
-
-  jobjectArray retArray;
-  jbyteArray outArray, intsByteArray;
-  unsigned char intsarray[1];
-  secp256k1_pubkey pubkey;
-  unsigned char nonce_res[32];
-  size_t outputLen = 32;
-
-  int ret = secp256k1_ec_pubkey_parse(ctx, &pubkey, pubdata, publen);
-
-  if (ret) {
-    ret = secp256k1_ecdh(
-      ctx,
-      nonce_res,
-      &pubkey,
-      secdata
-    );
-  }
-
-  intsarray[0] = ret;
-
-  retArray = (*env)->NewObjectArray(env, 2,
-    (*env)->FindClass(env, "[B"),
-    (*env)->NewByteArray(env, 1));
-
-  outArray = (*env)->NewByteArray(env, outputLen);
-  (*env)->SetByteArrayRegion(env, outArray, 0, 32, (jbyte*)nonce_res);
-  (*env)->SetObjectArrayElement(env, retArray, 0, outArray);
-
-  intsByteArray = (*env)->NewByteArray(env, 1);
-  (*env)->SetByteArrayRegion(env, intsByteArray, 0, 1, (jbyte*)intsarray);
-  (*env)->SetObjectArrayElement(env, retArray, 1, intsByteArray);
-
-  (void)classObject;
-
-  return retArray;
-}
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_NativeSecp256k1.h b/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_NativeSecp256k1.h
deleted file mode 100644
index fe613c9e9..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_NativeSecp256k1.h
+++ /dev/null
@@ -1,119 +0,0 @@
-/* DO NOT EDIT THIS FILE - it is machine generated */
-#include <jni.h>
-#include "include/secp256k1.h"
-/* Header for class org_bitcoin_NativeSecp256k1 */
-
-#ifndef _Included_org_bitcoin_NativeSecp256k1
-#define _Included_org_bitcoin_NativeSecp256k1
-#ifdef __cplusplus
-extern "C" {
-#endif
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ctx_clone
- * Signature: (J)J
- */
-SECP256K1_API jlong JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ctx_1clone
-  (JNIEnv *, jclass, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_context_randomize
- * Signature: (Ljava/nio/ByteBuffer;J)I
- */
-SECP256K1_API jint JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1context_1randomize
-  (JNIEnv *, jclass, jobject, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_privkey_tweak_add
- * Signature: (Ljava/nio/ByteBuffer;J)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1privkey_1tweak_1add
-  (JNIEnv *, jclass, jobject, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_privkey_tweak_mul
- * Signature: (Ljava/nio/ByteBuffer;J)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1privkey_1tweak_1mul
-  (JNIEnv *, jclass, jobject, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_pubkey_tweak_add
- * Signature: (Ljava/nio/ByteBuffer;JI)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1pubkey_1tweak_1add
-  (JNIEnv *, jclass, jobject, jlong, jint);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_pubkey_tweak_mul
- * Signature: (Ljava/nio/ByteBuffer;JI)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1pubkey_1tweak_1mul
-  (JNIEnv *, jclass, jobject, jlong, jint);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_destroy_context
- * Signature: (J)V
- */
-SECP256K1_API void JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1destroy_1context
-  (JNIEnv *, jclass, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ecdsa_verify
- * Signature: (Ljava/nio/ByteBuffer;JII)I
- */
-SECP256K1_API jint JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdsa_1verify
-  (JNIEnv *, jclass, jobject, jlong, jint, jint);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ecdsa_sign
- * Signature: (Ljava/nio/ByteBuffer;J)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdsa_1sign
-  (JNIEnv *, jclass, jobject, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ec_seckey_verify
- * Signature: (Ljava/nio/ByteBuffer;J)I
- */
-SECP256K1_API jint JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ec_1seckey_1verify
-  (JNIEnv *, jclass, jobject, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ec_pubkey_create
- * Signature: (Ljava/nio/ByteBuffer;J)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ec_1pubkey_1create
-  (JNIEnv *, jclass, jobject, jlong);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ec_pubkey_parse
- * Signature: (Ljava/nio/ByteBuffer;JI)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ec_1pubkey_1parse
-  (JNIEnv *, jclass, jobject, jlong, jint);
-
-/*
- * Class:     org_bitcoin_NativeSecp256k1
- * Method:    secp256k1_ecdh
- * Signature: (Ljava/nio/ByteBuffer;JI)[[B
- */
-SECP256K1_API jobjectArray JNICALL Java_org_bitcoin_NativeSecp256k1_secp256k1_1ecdh
-  (JNIEnv* env, jclass classObject, jobject byteBufferObject, jlong ctx_l, jint publen);
-
-
-#ifdef __cplusplus
-}
-#endif
-#endif
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_Secp256k1Context.c b/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_Secp256k1Context.c
deleted file mode 100644
index a52939e7e..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_Secp256k1Context.c
+++ /dev/null
@@ -1,15 +0,0 @@
-#include <stdlib.h>
-#include <stdint.h>
-#include "org_bitcoin_Secp256k1Context.h"
-#include "include/secp256k1.h"
-
-SECP256K1_API jlong JNICALL Java_org_bitcoin_Secp256k1Context_secp256k1_1init_1context
-  (JNIEnv* env, jclass classObject)
-{
-  secp256k1_context *ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
-
-  (void)classObject;(void)env;
-
-  return (uintptr_t)ctx;
-}
-
diff --git a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_Secp256k1Context.h b/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_Secp256k1Context.h
deleted file mode 100644
index 0d2bc84b7..000000000
--- a/crypto/secp256k1/libsecp256k1/src/java/org_bitcoin_Secp256k1Context.h
+++ /dev/null
@@ -1,22 +0,0 @@
-/* DO NOT EDIT THIS FILE - it is machine generated */
-#include <jni.h>
-#include "include/secp256k1.h"
-/* Header for class org_bitcoin_Secp256k1Context */
-
-#ifndef _Included_org_bitcoin_Secp256k1Context
-#define _Included_org_bitcoin_Secp256k1Context
-#ifdef __cplusplus
-extern "C" {
-#endif
-/*
- * Class:     org_bitcoin_Secp256k1Context
- * Method:    secp256k1_init_context
- * Signature: ()J
- */
-SECP256K1_API jlong JNICALL Java_org_bitcoin_Secp256k1Context_secp256k1_1init_1context
-  (JNIEnv *, jclass);
-
-#ifdef __cplusplus
-}
-#endif
-#endif
diff --git a/crypto/secp256k1/libsecp256k1/src/modules/ecdh/main_impl.h b/crypto/secp256k1/libsecp256k1/src/modules/ecdh/main_impl.h
index 9e30fb73d..07a25b80d 100644
--- a/crypto/secp256k1/libsecp256k1/src/modules/ecdh/main_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/modules/ecdh/main_impl.h
@@ -4,51 +4,68 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_MODULE_ECDH_MAIN_
-#define _SECP256K1_MODULE_ECDH_MAIN_
+#ifndef SECP256K1_MODULE_ECDH_MAIN_H
+#define SECP256K1_MODULE_ECDH_MAIN_H
 
 #include "include/secp256k1_ecdh.h"
 #include "ecmult_const_impl.h"
 
-int secp256k1_ecdh(const secp256k1_context* ctx, unsigned char *result, const secp256k1_pubkey *point, const unsigned char *scalar) {
+static int ecdh_hash_function_sha256(unsigned char *output, const unsigned char *x32, const unsigned char *y32, void *data) {
+    unsigned char version = (y32[31] & 0x01) | 0x02;
+    secp256k1_sha256 sha;
+    (void)data;
+
+    secp256k1_sha256_initialize(&sha);
+    secp256k1_sha256_write(&sha, &version, 1);
+    secp256k1_sha256_write(&sha, x32, 32);
+    secp256k1_sha256_finalize(&sha, output);
+
+    return 1;
+}
+
+const secp256k1_ecdh_hash_function secp256k1_ecdh_hash_function_sha256 = ecdh_hash_function_sha256;
+const secp256k1_ecdh_hash_function secp256k1_ecdh_hash_function_default = ecdh_hash_function_sha256;
+
+int secp256k1_ecdh(const secp256k1_context* ctx, unsigned char *output, const secp256k1_pubkey *point, const unsigned char *scalar, secp256k1_ecdh_hash_function hashfp, void *data) {
     int ret = 0;
     int overflow = 0;
     secp256k1_gej res;
     secp256k1_ge pt;
     secp256k1_scalar s;
+    unsigned char x[32];
+    unsigned char y[32];
+
     VERIFY_CHECK(ctx != NULL);
-    ARG_CHECK(result != NULL);
+    ARG_CHECK(output != NULL);
     ARG_CHECK(point != NULL);
     ARG_CHECK(scalar != NULL);
 
+    if (hashfp == NULL) {
+        hashfp = secp256k1_ecdh_hash_function_default;
+    }
+
     secp256k1_pubkey_load(ctx, &pt, point);
     secp256k1_scalar_set_b32(&s, scalar, &overflow);
-    if (overflow || secp256k1_scalar_is_zero(&s)) {
-        ret = 0;
-    } else {
-        unsigned char x[32];
-        unsigned char y[1];
-        secp256k1_sha256_t sha;
-
-        secp256k1_ecmult_const(&res, &pt, &s);
-        secp256k1_ge_set_gej(&pt, &res);
-        /* Compute a hash of the point in compressed form
-         * Note we cannot use secp256k1_eckey_pubkey_serialize here since it does not
-         * expect its output to be secret and has a timing sidechannel. */
-        secp256k1_fe_normalize(&pt.x);
-        secp256k1_fe_normalize(&pt.y);
-        secp256k1_fe_get_b32(x, &pt.x);
-        y[0] = 0x02 | secp256k1_fe_is_odd(&pt.y);
-
-        secp256k1_sha256_initialize(&sha);
-        secp256k1_sha256_write(&sha, y, sizeof(y));
-        secp256k1_sha256_write(&sha, x, sizeof(x));
-        secp256k1_sha256_finalize(&sha, result);
-        ret = 1;
-    }
 
+    overflow |= secp256k1_scalar_is_zero(&s);
+    secp256k1_scalar_cmov(&s, &secp256k1_scalar_one, overflow);
+
+    secp256k1_ecmult_const(&res, &pt, &s, 256);
+    secp256k1_ge_set_gej(&pt, &res);
+
+    /* Compute a hash of the point */
+    secp256k1_fe_normalize(&pt.x);
+    secp256k1_fe_normalize(&pt.y);
+    secp256k1_fe_get_b32(x, &pt.x);
+    secp256k1_fe_get_b32(y, &pt.y);
+
+    ret = hashfp(output, x, y, data);
+
+    memset(x, 0, 32);
+    memset(y, 0, 32);
     secp256k1_scalar_clear(&s);
-    return ret;
+
+    return !!ret & !overflow;
 }
 
-#endif
+#endif /* SECP256K1_MODULE_ECDH_MAIN_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/modules/ecdh/tests_impl.h b/crypto/secp256k1/libsecp256k1/src/modules/ecdh/tests_impl.h
index 85a5d0a9a..fe26e8fb6 100644
--- a/crypto/secp256k1/libsecp256k1/src/modules/ecdh/tests_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/modules/ecdh/tests_impl.h
@@ -4,8 +4,25 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_MODULE_ECDH_TESTS_
-#define _SECP256K1_MODULE_ECDH_TESTS_
+#ifndef SECP256K1_MODULE_ECDH_TESTS_H
+#define SECP256K1_MODULE_ECDH_TESTS_H
+
+int ecdh_hash_function_test_fail(unsigned char *output, const unsigned char *x, const unsigned char *y, void *data) {
+    (void)output;
+    (void)x;
+    (void)y;
+    (void)data;
+    return 0;
+}
+
+int ecdh_hash_function_custom(unsigned char *output, const unsigned char *x, const unsigned char *y, void *data) {
+    (void)data;
+    /* Save x and y as uncompressed public key */
+    output[0] = 0x04;
+    memcpy(output + 1, x, 32);
+    memcpy(output + 33, y, 32);
+    return 1;
+}
 
 void test_ecdh_api(void) {
     /* Setup context that just counts errors */
@@ -21,15 +38,15 @@ void test_ecdh_api(void) {
     CHECK(secp256k1_ec_pubkey_create(tctx, &point, s_one) == 1);
 
     /* Check all NULLs are detected */
-    CHECK(secp256k1_ecdh(tctx, res, &point, s_one) == 1);
+    CHECK(secp256k1_ecdh(tctx, res, &point, s_one, NULL, NULL) == 1);
     CHECK(ecount == 0);
-    CHECK(secp256k1_ecdh(tctx, NULL, &point, s_one) == 0);
+    CHECK(secp256k1_ecdh(tctx, NULL, &point, s_one, NULL, NULL) == 0);
     CHECK(ecount == 1);
-    CHECK(secp256k1_ecdh(tctx, res, NULL, s_one) == 0);
+    CHECK(secp256k1_ecdh(tctx, res, NULL, s_one, NULL, NULL) == 0);
     CHECK(ecount == 2);
-    CHECK(secp256k1_ecdh(tctx, res, &point, NULL) == 0);
+    CHECK(secp256k1_ecdh(tctx, res, &point, NULL, NULL, NULL) == 0);
     CHECK(ecount == 3);
-    CHECK(secp256k1_ecdh(tctx, res, &point, s_one) == 1);
+    CHECK(secp256k1_ecdh(tctx, res, &point, s_one, NULL, NULL) == 1);
     CHECK(ecount == 3);
 
     /* Cleanup */
@@ -44,29 +61,36 @@ void test_ecdh_generator_basepoint(void) {
     s_one[31] = 1;
     /* Check against pubkey creation when the basepoint is the generator */
     for (i = 0; i < 100; ++i) {
-        secp256k1_sha256_t sha;
+        secp256k1_sha256 sha;
         unsigned char s_b32[32];
-        unsigned char output_ecdh[32];
+        unsigned char output_ecdh[65];
         unsigned char output_ser[32];
-        unsigned char point_ser[33];
+        unsigned char point_ser[65];
         size_t point_ser_len = sizeof(point_ser);
         secp256k1_scalar s;
 
         random_scalar_order(&s);
         secp256k1_scalar_get_b32(s_b32, &s);
 
-        /* compute using ECDH function */
         CHECK(secp256k1_ec_pubkey_create(ctx, &point[0], s_one) == 1);
-        CHECK(secp256k1_ecdh(ctx, output_ecdh, &point[0], s_b32) == 1);
-        /* compute "explicitly" */
         CHECK(secp256k1_ec_pubkey_create(ctx, &point[1], s_b32) == 1);
+
+        /* compute using ECDH function with custom hash function */
+        CHECK(secp256k1_ecdh(ctx, output_ecdh, &point[0], s_b32, ecdh_hash_function_custom, NULL) == 1);
+        /* compute "explicitly" */
+        CHECK(secp256k1_ec_pubkey_serialize(ctx, point_ser, &point_ser_len, &point[1], SECP256K1_EC_UNCOMPRESSED) == 1);
+        /* compare */
+        CHECK(memcmp(output_ecdh, point_ser, 65) == 0);
+
+        /* compute using ECDH function with default hash function */
+        CHECK(secp256k1_ecdh(ctx, output_ecdh, &point[0], s_b32, NULL, NULL) == 1);
+        /* compute "explicitly" */
         CHECK(secp256k1_ec_pubkey_serialize(ctx, point_ser, &point_ser_len, &point[1], SECP256K1_EC_COMPRESSED) == 1);
-        CHECK(point_ser_len == sizeof(point_ser));
         secp256k1_sha256_initialize(&sha);
         secp256k1_sha256_write(&sha, point_ser, point_ser_len);
         secp256k1_sha256_finalize(&sha, output_ser);
         /* compare */
-        CHECK(memcmp(output_ecdh, output_ser, sizeof(output_ser)) == 0);
+        CHECK(memcmp(output_ecdh, output_ser, 32) == 0);
     }
 }
 
@@ -89,11 +113,14 @@ void test_bad_scalar(void) {
     CHECK(secp256k1_ec_pubkey_create(ctx, &point, s_rand) == 1);
 
     /* Try to multiply it by bad values */
-    CHECK(secp256k1_ecdh(ctx, output, &point, s_zero) == 0);
-    CHECK(secp256k1_ecdh(ctx, output, &point, s_overflow) == 0);
+    CHECK(secp256k1_ecdh(ctx, output, &point, s_zero, NULL, NULL) == 0);
+    CHECK(secp256k1_ecdh(ctx, output, &point, s_overflow, NULL, NULL) == 0);
     /* ...and a good one */
     s_overflow[31] -= 1;
-    CHECK(secp256k1_ecdh(ctx, output, &point, s_overflow) == 1);
+    CHECK(secp256k1_ecdh(ctx, output, &point, s_overflow, NULL, NULL) == 1);
+
+    /* Hash function failure results in ecdh failure */
+    CHECK(secp256k1_ecdh(ctx, output, &point, s_overflow, ecdh_hash_function_test_fail, NULL) == 0);
 }
 
 void run_ecdh_tests(void) {
@@ -102,4 +129,4 @@ void run_ecdh_tests(void) {
     test_bad_scalar();
 }
 
-#endif
+#endif /* SECP256K1_MODULE_ECDH_TESTS_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/modules/recovery/main_impl.h b/crypto/secp256k1/libsecp256k1/src/modules/recovery/main_impl.h
old mode 100755
new mode 100644
index c6fbe2398..ed356e53a
--- a/crypto/secp256k1/libsecp256k1/src/modules/recovery/main_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/modules/recovery/main_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_MODULE_RECOVERY_MAIN_
-#define _SECP256K1_MODULE_RECOVERY_MAIN_
+#ifndef SECP256K1_MODULE_RECOVERY_MAIN_H
+#define SECP256K1_MODULE_RECOVERY_MAIN_H
 
 #include "include/secp256k1_recovery.h"
 
@@ -147,7 +147,7 @@ int secp256k1_ecdsa_sign_recoverable(const secp256k1_context* ctx, secp256k1_ecd
                 break;
             }
             secp256k1_scalar_set_b32(&non, nonce32, &overflow);
-            if (!secp256k1_scalar_is_zero(&non) && !overflow) {
+            if (!overflow && !secp256k1_scalar_is_zero(&non)) {
                 if (secp256k1_ecdsa_sig_sign(&ctx->ecmult_gen_ctx, &r, &s, &sec, &msg, &non, &recid)) {
                     break;
                 }
@@ -190,4 +190,4 @@ int secp256k1_ecdsa_recover(const secp256k1_context* ctx, secp256k1_pubkey *pubk
     }
 }
 
-#endif
+#endif /* SECP256K1_MODULE_RECOVERY_MAIN_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/modules/recovery/tests_impl.h b/crypto/secp256k1/libsecp256k1/src/modules/recovery/tests_impl.h
index 765c7dd81..38a533a75 100644
--- a/crypto/secp256k1/libsecp256k1/src/modules/recovery/tests_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/modules/recovery/tests_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_MODULE_RECOVERY_TESTS_
-#define _SECP256K1_MODULE_RECOVERY_TESTS_
+#ifndef SECP256K1_MODULE_RECOVERY_TESTS_H
+#define SECP256K1_MODULE_RECOVERY_TESTS_H
 
 static int recovery_test_nonce_function(unsigned char *nonce32, const unsigned char *msg32, const unsigned char *key32, const unsigned char *algo16, void *data, unsigned int counter) {
     (void) msg32;
@@ -215,7 +215,7 @@ void test_ecdsa_recovery_edge_cases(void) {
     };
     const unsigned char sig64[64] = {
         /* Generated by signing the above message with nonce 'This is the nonce we will use...'
-         * and secret key 0 (which is not valid), resulting in recid 0. */
+         * and secret key 0 (which is not valid), resulting in recid 1. */
         0x67, 0xCB, 0x28, 0x5F, 0x9C, 0xD1, 0x94, 0xE8,
         0x40, 0xD6, 0x29, 0x39, 0x7A, 0xF5, 0x56, 0x96,
         0x62, 0xFD, 0xE4, 0x46, 0x49, 0x99, 0x59, 0x63,
@@ -390,4 +390,4 @@ void run_recovery_tests(void) {
     test_ecdsa_recovery_edge_cases();
 }
 
-#endif
+#endif /* SECP256K1_MODULE_RECOVERY_TESTS_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/num.h b/crypto/secp256k1/libsecp256k1/src/num.h
index eff842200..49f2dd791 100644
--- a/crypto/secp256k1/libsecp256k1/src/num.h
+++ b/crypto/secp256k1/libsecp256k1/src/num.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_NUM_
-#define _SECP256K1_NUM_
+#ifndef SECP256K1_NUM_H
+#define SECP256K1_NUM_H
 
 #ifndef USE_NUM_NONE
 
@@ -54,7 +54,7 @@ static void secp256k1_num_mul(secp256k1_num *r, const secp256k1_num *a, const se
     even if r was negative. */
 static void secp256k1_num_mod(secp256k1_num *r, const secp256k1_num *m);
 
-/** Right-shift the passed number by bits. */
+/** Right-shift the passed number by bits bits. */
 static void secp256k1_num_shift(secp256k1_num *r, int bits);
 
 /** Check whether a number is zero. */
@@ -71,4 +71,4 @@ static void secp256k1_num_negate(secp256k1_num *r);
 
 #endif
 
-#endif
+#endif /* SECP256K1_NUM_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/num_gmp.h b/crypto/secp256k1/libsecp256k1/src/num_gmp.h
index 7dd813088..3619844bd 100644
--- a/crypto/secp256k1/libsecp256k1/src/num_gmp.h
+++ b/crypto/secp256k1/libsecp256k1/src/num_gmp.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_NUM_REPR_
-#define _SECP256K1_NUM_REPR_
+#ifndef SECP256K1_NUM_REPR_H
+#define SECP256K1_NUM_REPR_H
 
 #include <gmp.h>
 
@@ -17,4 +17,4 @@ typedef struct {
     int limbs;
 } secp256k1_num;
 
-#endif
+#endif /* SECP256K1_NUM_REPR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/num_gmp_impl.h b/crypto/secp256k1/libsecp256k1/src/num_gmp_impl.h
index 3a46495ee..0ae2a8ba0 100644
--- a/crypto/secp256k1/libsecp256k1/src/num_gmp_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/num_gmp_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_NUM_REPR_IMPL_H_
-#define _SECP256K1_NUM_REPR_IMPL_H_
+#ifndef SECP256K1_NUM_REPR_IMPL_H
+#define SECP256K1_NUM_REPR_IMPL_H
 
 #include <string.h>
 #include <stdlib.h>
@@ -285,4 +285,4 @@ static void secp256k1_num_negate(secp256k1_num *r) {
     r->neg ^= 1;
 }
 
-#endif
+#endif /* SECP256K1_NUM_REPR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/num_impl.h b/crypto/secp256k1/libsecp256k1/src/num_impl.h
index 0b0e3a072..c45193b03 100644
--- a/crypto/secp256k1/libsecp256k1/src/num_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/num_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_NUM_IMPL_H_
-#define _SECP256K1_NUM_IMPL_H_
+#ifndef SECP256K1_NUM_IMPL_H
+#define SECP256K1_NUM_IMPL_H
 
 #if defined HAVE_CONFIG_H
 #include "libsecp256k1-config.h"
@@ -21,4 +21,4 @@
 #error "Please select num implementation"
 #endif
 
-#endif
+#endif /* SECP256K1_NUM_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar.h b/crypto/secp256k1/libsecp256k1/src/scalar.h
index 27e9d8375..6dc7574ca 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_
-#define _SECP256K1_SCALAR_
+#ifndef SECP256K1_SCALAR_H
+#define SECP256K1_SCALAR_H
 
 #include "num.h"
 
@@ -32,9 +32,17 @@ static unsigned int secp256k1_scalar_get_bits(const secp256k1_scalar *a, unsigne
 /** Access bits from a scalar. Not constant time. */
 static unsigned int secp256k1_scalar_get_bits_var(const secp256k1_scalar *a, unsigned int offset, unsigned int count);
 
-/** Set a scalar from a big endian byte array. */
+/** Set a scalar from a big endian byte array. The scalar will be reduced modulo group order `n`.
+ * In:      bin:        pointer to a 32-byte array.
+ * Out:     r:          scalar to be set.
+ *          overflow:   non-zero if the scalar was bigger or equal to `n` before reduction, zero otherwise (can be NULL).
+ */
 static void secp256k1_scalar_set_b32(secp256k1_scalar *r, const unsigned char *bin, int *overflow);
 
+/** Set a scalar from a big endian byte array and returns 1 if it is a valid
+ *  seckey and 0 otherwise. */
+static int secp256k1_scalar_set_b32_seckey(secp256k1_scalar *r, const unsigned char *bin);
+
 /** Set a scalar to an unsigned integer. */
 static void secp256k1_scalar_set_int(secp256k1_scalar *r, unsigned int v);
 
@@ -103,4 +111,7 @@ static void secp256k1_scalar_split_lambda(secp256k1_scalar *r1, secp256k1_scalar
 /** Multiply a and b (without taking the modulus!), divide by 2**shift, and round to the nearest integer. Shift must be at least 256. */
 static void secp256k1_scalar_mul_shift_var(secp256k1_scalar *r, const secp256k1_scalar *a, const secp256k1_scalar *b, unsigned int shift);
 
-#endif
+/** If flag is true, set *r equal to *a; otherwise leave it. Constant-time. */
+static void secp256k1_scalar_cmov(secp256k1_scalar *r, const secp256k1_scalar *a, int flag);
+
+#endif /* SECP256K1_SCALAR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_4x64.h b/crypto/secp256k1/libsecp256k1/src/scalar_4x64.h
index cff406038..19c7495d1 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_4x64.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_4x64.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_REPR_
-#define _SECP256K1_SCALAR_REPR_
+#ifndef SECP256K1_SCALAR_REPR_H
+#define SECP256K1_SCALAR_REPR_H
 
 #include <stdint.h>
 
@@ -16,4 +16,4 @@ typedef struct {
 
 #define SECP256K1_SCALAR_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {{((uint64_t)(d1)) << 32 | (d0), ((uint64_t)(d3)) << 32 | (d2), ((uint64_t)(d5)) << 32 | (d4), ((uint64_t)(d7)) << 32 | (d6)}}
 
-#endif
+#endif /* SECP256K1_SCALAR_REPR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_4x64_impl.h b/crypto/secp256k1/libsecp256k1/src/scalar_4x64_impl.h
index 56e7bd82a..2d81006c0 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_4x64_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_4x64_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_REPR_IMPL_H_
-#define _SECP256K1_SCALAR_REPR_IMPL_H_
+#ifndef SECP256K1_SCALAR_REPR_IMPL_H
+#define SECP256K1_SCALAR_REPR_IMPL_H
 
 /* Limbs of the secp256k1 order. */
 #define SECP256K1_N_0 ((uint64_t)0xBFD25E8CD0364141ULL)
@@ -376,7 +376,7 @@ static void secp256k1_scalar_reduce_512(secp256k1_scalar *r, const uint64_t *l)
     /* extract m6 */
     "movq %%r8, %q6\n"
     : "=g"(m0), "=g"(m1), "=g"(m2), "=g"(m3), "=g"(m4), "=g"(m5), "=g"(m6)
-    : "S"(l), "n"(SECP256K1_N_C_0), "n"(SECP256K1_N_C_1)
+    : "S"(l), "i"(SECP256K1_N_C_0), "i"(SECP256K1_N_C_1)
     : "rax", "rdx", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "cc");
 
     /* Reduce 385 bits into 258. */
@@ -455,7 +455,7 @@ static void secp256k1_scalar_reduce_512(secp256k1_scalar *r, const uint64_t *l)
     /* extract p4 */
     "movq %%r9, %q4\n"
     : "=&g"(p0), "=&g"(p1), "=&g"(p2), "=g"(p3), "=g"(p4)
-    : "g"(m0), "g"(m1), "g"(m2), "g"(m3), "g"(m4), "g"(m5), "g"(m6), "n"(SECP256K1_N_C_0), "n"(SECP256K1_N_C_1)
+    : "g"(m0), "g"(m1), "g"(m2), "g"(m3), "g"(m4), "g"(m5), "g"(m6), "i"(SECP256K1_N_C_0), "i"(SECP256K1_N_C_1)
     : "rax", "rdx", "r8", "r9", "r10", "r11", "r12", "r13", "cc");
 
     /* Reduce 258 bits into 256. */
@@ -501,7 +501,7 @@ static void secp256k1_scalar_reduce_512(secp256k1_scalar *r, const uint64_t *l)
     /* Extract c */
     "movq %%r9, %q0\n"
     : "=g"(c)
-    : "g"(p0), "g"(p1), "g"(p2), "g"(p3), "g"(p4), "D"(r), "n"(SECP256K1_N_C_0), "n"(SECP256K1_N_C_1)
+    : "g"(p0), "g"(p1), "g"(p2), "g"(p3), "g"(p4), "D"(r), "i"(SECP256K1_N_C_0), "i"(SECP256K1_N_C_1)
     : "rax", "rdx", "r8", "r9", "r10", "cc", "memory");
 #else
     uint128_t c;
@@ -946,4 +946,14 @@ SECP256K1_INLINE static void secp256k1_scalar_mul_shift_var(secp256k1_scalar *r,
     secp256k1_scalar_cadd_bit(r, 0, (l[(shift - 1) >> 6] >> ((shift - 1) & 0x3f)) & 1);
 }
 
-#endif
+static SECP256K1_INLINE void secp256k1_scalar_cmov(secp256k1_scalar *r, const secp256k1_scalar *a, int flag) {
+    uint64_t mask0, mask1;
+    mask0 = flag + ~((uint64_t)0);
+    mask1 = ~mask0;
+    r->d[0] = (r->d[0] & mask0) | (a->d[0] & mask1);
+    r->d[1] = (r->d[1] & mask0) | (a->d[1] & mask1);
+    r->d[2] = (r->d[2] & mask0) | (a->d[2] & mask1);
+    r->d[3] = (r->d[3] & mask0) | (a->d[3] & mask1);
+}
+
+#endif /* SECP256K1_SCALAR_REPR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_8x32.h b/crypto/secp256k1/libsecp256k1/src/scalar_8x32.h
index 1319664f6..2c9a348e2 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_8x32.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_8x32.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_REPR_
-#define _SECP256K1_SCALAR_REPR_
+#ifndef SECP256K1_SCALAR_REPR_H
+#define SECP256K1_SCALAR_REPR_H
 
 #include <stdint.h>
 
@@ -16,4 +16,4 @@ typedef struct {
 
 #define SECP256K1_SCALAR_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {{(d0), (d1), (d2), (d3), (d4), (d5), (d6), (d7)}}
 
-#endif
+#endif /* SECP256K1_SCALAR_REPR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_8x32_impl.h b/crypto/secp256k1/libsecp256k1/src/scalar_8x32_impl.h
index aae4f35c0..f5042891f 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_8x32_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_8x32_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_REPR_IMPL_H_
-#define _SECP256K1_SCALAR_REPR_IMPL_H_
+#ifndef SECP256K1_SCALAR_REPR_IMPL_H
+#define SECP256K1_SCALAR_REPR_IMPL_H
 
 /* Limbs of the secp256k1 order. */
 #define SECP256K1_N_0 ((uint32_t)0xD0364141UL)
@@ -718,4 +718,18 @@ SECP256K1_INLINE static void secp256k1_scalar_mul_shift_var(secp256k1_scalar *r,
     secp256k1_scalar_cadd_bit(r, 0, (l[(shift - 1) >> 5] >> ((shift - 1) & 0x1f)) & 1);
 }
 
-#endif
+static SECP256K1_INLINE void secp256k1_scalar_cmov(secp256k1_scalar *r, const secp256k1_scalar *a, int flag) {
+    uint32_t mask0, mask1;
+    mask0 = flag + ~((uint32_t)0);
+    mask1 = ~mask0;
+    r->d[0] = (r->d[0] & mask0) | (a->d[0] & mask1);
+    r->d[1] = (r->d[1] & mask0) | (a->d[1] & mask1);
+    r->d[2] = (r->d[2] & mask0) | (a->d[2] & mask1);
+    r->d[3] = (r->d[3] & mask0) | (a->d[3] & mask1);
+    r->d[4] = (r->d[4] & mask0) | (a->d[4] & mask1);
+    r->d[5] = (r->d[5] & mask0) | (a->d[5] & mask1);
+    r->d[6] = (r->d[6] & mask0) | (a->d[6] & mask1);
+    r->d[7] = (r->d[7] & mask0) | (a->d[7] & mask1);
+}
+
+#endif /* SECP256K1_SCALAR_REPR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_impl.h b/crypto/secp256k1/libsecp256k1/src/scalar_impl.h
index f5b237640..70cd73db0 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_impl.h
@@ -4,11 +4,11 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_IMPL_H_
-#define _SECP256K1_SCALAR_IMPL_H_
+#ifndef SECP256K1_SCALAR_IMPL_H
+#define SECP256K1_SCALAR_IMPL_H
 
-#include "group.h"
 #include "scalar.h"
+#include "util.h"
 
 #if defined HAVE_CONFIG_H
 #include "libsecp256k1-config.h"
@@ -24,6 +24,9 @@
 #error "Please select scalar implementation"
 #endif
 
+static const secp256k1_scalar secp256k1_scalar_one = SECP256K1_SCALAR_CONST(0, 0, 0, 0, 0, 0, 0, 1);
+static const secp256k1_scalar secp256k1_scalar_zero = SECP256K1_SCALAR_CONST(0, 0, 0, 0, 0, 0, 0, 0);
+
 #ifndef USE_NUM_NONE
 static void secp256k1_scalar_get_num(secp256k1_num *r, const secp256k1_scalar *a) {
     unsigned char c[32];
@@ -52,6 +55,12 @@ static void secp256k1_scalar_order_get_num(secp256k1_num *r) {
 }
 #endif
 
+static int secp256k1_scalar_set_b32_seckey(secp256k1_scalar *r, const unsigned char *bin) {
+    int overflow;
+    secp256k1_scalar_set_b32(r, bin, &overflow);
+    return (!overflow) & (!secp256k1_scalar_is_zero(r));
+}
+
 static void secp256k1_scalar_inverse(secp256k1_scalar *r, const secp256k1_scalar *x) {
 #if defined(EXHAUSTIVE_TEST_ORDER)
     int i;
@@ -66,88 +75,79 @@ static void secp256k1_scalar_inverse(secp256k1_scalar *r, const secp256k1_scalar
 #else
     secp256k1_scalar *t;
     int i;
-    /* First compute x ^ (2^N - 1) for some values of N. */
-    secp256k1_scalar x2, x3, x4, x6, x7, x8, x15, x30, x60, x120, x127;
-
-    secp256k1_scalar_sqr(&x2,  x);
-    secp256k1_scalar_mul(&x2, &x2,  x);
+    /* First compute xN as x ^ (2^N - 1) for some values of N,
+     * and uM as x ^ M for some values of M. */
+    secp256k1_scalar x2, x3, x6, x8, x14, x28, x56, x112, x126;
+    secp256k1_scalar u2, u5, u9, u11, u13;
 
-    secp256k1_scalar_sqr(&x3, &x2);
-    secp256k1_scalar_mul(&x3, &x3,  x);
+    secp256k1_scalar_sqr(&u2, x);
+    secp256k1_scalar_mul(&x2, &u2,  x);
+    secp256k1_scalar_mul(&u5, &u2, &x2);
+    secp256k1_scalar_mul(&x3, &u5,  &u2);
+    secp256k1_scalar_mul(&u9, &x3, &u2);
+    secp256k1_scalar_mul(&u11, &u9, &u2);
+    secp256k1_scalar_mul(&u13, &u11, &u2);
 
-    secp256k1_scalar_sqr(&x4, &x3);
-    secp256k1_scalar_mul(&x4, &x4,  x);
-
-    secp256k1_scalar_sqr(&x6, &x4);
+    secp256k1_scalar_sqr(&x6, &u13);
     secp256k1_scalar_sqr(&x6, &x6);
-    secp256k1_scalar_mul(&x6, &x6, &x2);
-
-    secp256k1_scalar_sqr(&x7, &x6);
-    secp256k1_scalar_mul(&x7, &x7,  x);
+    secp256k1_scalar_mul(&x6, &x6, &u11);
 
-    secp256k1_scalar_sqr(&x8, &x7);
-    secp256k1_scalar_mul(&x8, &x8,  x);
+    secp256k1_scalar_sqr(&x8, &x6);
+    secp256k1_scalar_sqr(&x8, &x8);
+    secp256k1_scalar_mul(&x8, &x8,  &x2);
 
-    secp256k1_scalar_sqr(&x15, &x8);
-    for (i = 0; i < 6; i++) {
-        secp256k1_scalar_sqr(&x15, &x15);
+    secp256k1_scalar_sqr(&x14, &x8);
+    for (i = 0; i < 5; i++) {
+        secp256k1_scalar_sqr(&x14, &x14);
     }
-    secp256k1_scalar_mul(&x15, &x15, &x7);
+    secp256k1_scalar_mul(&x14, &x14, &x6);
 
-    secp256k1_scalar_sqr(&x30, &x15);
-    for (i = 0; i < 14; i++) {
-        secp256k1_scalar_sqr(&x30, &x30);
+    secp256k1_scalar_sqr(&x28, &x14);
+    for (i = 0; i < 13; i++) {
+        secp256k1_scalar_sqr(&x28, &x28);
     }
-    secp256k1_scalar_mul(&x30, &x30, &x15);
+    secp256k1_scalar_mul(&x28, &x28, &x14);
 
-    secp256k1_scalar_sqr(&x60, &x30);
-    for (i = 0; i < 29; i++) {
-        secp256k1_scalar_sqr(&x60, &x60);
+    secp256k1_scalar_sqr(&x56, &x28);
+    for (i = 0; i < 27; i++) {
+        secp256k1_scalar_sqr(&x56, &x56);
     }
-    secp256k1_scalar_mul(&x60, &x60, &x30);
+    secp256k1_scalar_mul(&x56, &x56, &x28);
 
-    secp256k1_scalar_sqr(&x120, &x60);
-    for (i = 0; i < 59; i++) {
-        secp256k1_scalar_sqr(&x120, &x120);
+    secp256k1_scalar_sqr(&x112, &x56);
+    for (i = 0; i < 55; i++) {
+        secp256k1_scalar_sqr(&x112, &x112);
     }
-    secp256k1_scalar_mul(&x120, &x120, &x60);
+    secp256k1_scalar_mul(&x112, &x112, &x56);
 
-    secp256k1_scalar_sqr(&x127, &x120);
-    for (i = 0; i < 6; i++) {
-        secp256k1_scalar_sqr(&x127, &x127);
+    secp256k1_scalar_sqr(&x126, &x112);
+    for (i = 0; i < 13; i++) {
+        secp256k1_scalar_sqr(&x126, &x126);
     }
-    secp256k1_scalar_mul(&x127, &x127, &x7);
+    secp256k1_scalar_mul(&x126, &x126, &x14);
 
-    /* Then accumulate the final result (t starts at x127). */
-    t = &x127;
-    for (i = 0; i < 2; i++) { /* 0 */
+    /* Then accumulate the final result (t starts at x126). */
+    t = &x126;
+    for (i = 0; i < 3; i++) {
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
+    secp256k1_scalar_mul(t, t, &u5); /* 101 */
     for (i = 0; i < 4; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
     secp256k1_scalar_mul(t, t, &x3); /* 111 */
-    for (i = 0; i < 2; i++) { /* 0 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 2; i++) { /* 0 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 2; i++) { /* 0 */
+    for (i = 0; i < 4; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 4; i++) { /* 0 */
+    secp256k1_scalar_mul(t, t, &u5); /* 101 */
+    for (i = 0; i < 5; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x3); /* 111 */
-    for (i = 0; i < 3; i++) { /* 0 */
+    secp256k1_scalar_mul(t, t, &u11); /* 1011 */
+    for (i = 0; i < 4; i++) {
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x2); /* 11 */
+    secp256k1_scalar_mul(t, t, &u11); /* 1011 */
     for (i = 0; i < 4; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
@@ -156,38 +156,26 @@ static void secp256k1_scalar_inverse(secp256k1_scalar *r, const secp256k1_scalar
         secp256k1_scalar_sqr(t, t);
     }
     secp256k1_scalar_mul(t, t, &x3); /* 111 */
-    for (i = 0; i < 4; i++) { /* 00 */
+    for (i = 0; i < 6; i++) { /* 00 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x2); /* 11 */
-    for (i = 0; i < 2; i++) { /* 0 */
+    secp256k1_scalar_mul(t, t, &u13); /* 1101 */
+    for (i = 0; i < 4; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 2; i++) { /* 0 */
+    secp256k1_scalar_mul(t, t, &u5); /* 101 */
+    for (i = 0; i < 3; i++) {
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
+    secp256k1_scalar_mul(t, t, &x3); /* 111 */
     for (i = 0; i < 5; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x4); /* 1111 */
-    for (i = 0; i < 2; i++) { /* 0 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 3; i++) { /* 00 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 4; i++) { /* 000 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 2; i++) { /* 0 */
+    secp256k1_scalar_mul(t, t, &u9); /* 1001 */
+    for (i = 0; i < 6; i++) { /* 000 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
+    secp256k1_scalar_mul(t, t, &u5); /* 101 */
     for (i = 0; i < 10; i++) { /* 0000000 */
         secp256k1_scalar_sqr(t, t);
     }
@@ -200,50 +188,34 @@ static void secp256k1_scalar_inverse(secp256k1_scalar *r, const secp256k1_scalar
         secp256k1_scalar_sqr(t, t);
     }
     secp256k1_scalar_mul(t, t, &x8); /* 11111111 */
-    for (i = 0; i < 2; i++) { /* 0 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 3; i++) { /* 00 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 3; i++) { /* 00 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
     for (i = 0; i < 5; i++) { /* 0 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x4); /* 1111 */
-    for (i = 0; i < 2; i++) { /* 0 */
+    secp256k1_scalar_mul(t, t, &u9); /* 1001 */
+    for (i = 0; i < 6; i++) { /* 00 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 5; i++) { /* 000 */
+    secp256k1_scalar_mul(t, t, &u11); /* 1011 */
+    for (i = 0; i < 4; i++) {
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x2); /* 11 */
-    for (i = 0; i < 4; i++) { /* 00 */
+    secp256k1_scalar_mul(t, t, &u13); /* 1101 */
+    for (i = 0; i < 5; i++) {
         secp256k1_scalar_sqr(t, t);
     }
     secp256k1_scalar_mul(t, t, &x2); /* 11 */
-    for (i = 0; i < 2; i++) { /* 0 */
+    for (i = 0; i < 6; i++) { /* 00 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
-    for (i = 0; i < 8; i++) { /* 000000 */
+    secp256k1_scalar_mul(t, t, &u13); /* 1101 */
+    for (i = 0; i < 10; i++) { /* 000000 */
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, &x2); /* 11 */
-    for (i = 0; i < 3; i++) { /* 0 */
-        secp256k1_scalar_sqr(t, t);
-    }
-    secp256k1_scalar_mul(t, t, &x2); /* 11 */
-    for (i = 0; i < 3; i++) { /* 00 */
+    secp256k1_scalar_mul(t, t, &u13); /* 1101 */
+    for (i = 0; i < 4; i++) {
         secp256k1_scalar_sqr(t, t);
     }
-    secp256k1_scalar_mul(t, t, x); /* 1 */
+    secp256k1_scalar_mul(t, t, &u9); /* 1001 */
     for (i = 0; i < 6; i++) { /* 00000 */
         secp256k1_scalar_sqr(t, t);
     }
@@ -367,4 +339,4 @@ static void secp256k1_scalar_split_lambda(secp256k1_scalar *r1, secp256k1_scalar
 #endif
 #endif
 
-#endif
+#endif /* SECP256K1_SCALAR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_low.h b/crypto/secp256k1/libsecp256k1/src/scalar_low.h
index 5574c44c7..2794a7f17 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_low.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_low.h
@@ -4,12 +4,14 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_REPR_
-#define _SECP256K1_SCALAR_REPR_
+#ifndef SECP256K1_SCALAR_REPR_H
+#define SECP256K1_SCALAR_REPR_H
 
 #include <stdint.h>
 
 /** A scalar modulo the group order of the secp256k1 curve. */
 typedef uint32_t secp256k1_scalar;
 
-#endif
+#define SECP256K1_SCALAR_CONST(d7, d6, d5, d4, d3, d2, d1, d0) (d0)
+
+#endif /* SECP256K1_SCALAR_REPR_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scalar_low_impl.h b/crypto/secp256k1/libsecp256k1/src/scalar_low_impl.h
index 4f94441f4..ad81f378b 100644
--- a/crypto/secp256k1/libsecp256k1/src/scalar_low_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/scalar_low_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_SCALAR_REPR_IMPL_H_
-#define _SECP256K1_SCALAR_REPR_IMPL_H_
+#ifndef SECP256K1_SCALAR_REPR_IMPL_H
+#define SECP256K1_SCALAR_REPR_IMPL_H
 
 #include "scalar.h"
 
@@ -38,8 +38,11 @@ static int secp256k1_scalar_add(secp256k1_scalar *r, const secp256k1_scalar *a,
 
 static void secp256k1_scalar_cadd_bit(secp256k1_scalar *r, unsigned int bit, int flag) {
     if (flag && bit < 32)
-        *r += (1 << bit);
+        *r += ((uint32_t)1 << bit);
 #ifdef VERIFY
+    VERIFY_CHECK(bit < 32);
+    /* Verify that adding (1 << bit) will not overflow any in-range scalar *r by overflowing the underlying uint32_t. */
+    VERIFY_CHECK(((uint32_t)1 << bit) - 1 <= UINT32_MAX - EXHAUSTIVE_TEST_ORDER);
     VERIFY_CHECK(secp256k1_scalar_check_overflow(r) == 0);
 #endif
 }
@@ -111,4 +114,11 @@ SECP256K1_INLINE static int secp256k1_scalar_eq(const secp256k1_scalar *a, const
     return *a == *b;
 }
 
-#endif
+static SECP256K1_INLINE void secp256k1_scalar_cmov(secp256k1_scalar *r, const secp256k1_scalar *a, int flag) {
+    uint32_t mask0, mask1;
+    mask0 = flag + ~((uint32_t)0);
+    mask1 = ~mask0;
+    *r = (*r & mask0) | (*a & mask1);
+}
+
+#endif /* SECP256K1_SCALAR_REPR_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/scratch.h b/crypto/secp256k1/libsecp256k1/src/scratch.h
new file mode 100644
index 000000000..77b35d126
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/src/scratch.h
@@ -0,0 +1,42 @@
+/**********************************************************************
+ * Copyright (c) 2017 Andrew Poelstra	                              *
+ * Distributed under the MIT software license, see the accompanying   *
+ * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
+ **********************************************************************/
+
+#ifndef _SECP256K1_SCRATCH_
+#define _SECP256K1_SCRATCH_
+
+/* The typedef is used internally; the struct name is used in the public API
+ * (where it is exposed as a different typedef) */
+typedef struct secp256k1_scratch_space_struct {
+    /** guard against interpreting this object as other types */
+    unsigned char magic[8];
+    /** actual allocated data */
+    void *data;
+    /** amount that has been allocated (i.e. `data + offset` is the next
+     *  available pointer)  */
+    size_t alloc_size;
+    /** maximum size available to allocate */
+    size_t max_size;
+} secp256k1_scratch;
+
+static secp256k1_scratch* secp256k1_scratch_create(const secp256k1_callback* error_callback, size_t max_size);
+
+static void secp256k1_scratch_destroy(const secp256k1_callback* error_callback, secp256k1_scratch* scratch);
+
+/** Returns an opaque object used to "checkpoint" a scratch space. Used
+ *  with `secp256k1_scratch_apply_checkpoint` to undo allocations. */
+static size_t secp256k1_scratch_checkpoint(const secp256k1_callback* error_callback, const secp256k1_scratch* scratch);
+
+/** Applies a check point received from `secp256k1_scratch_checkpoint`,
+ *  undoing all allocations since that point. */
+static void secp256k1_scratch_apply_checkpoint(const secp256k1_callback* error_callback, secp256k1_scratch* scratch, size_t checkpoint);
+
+/** Returns the maximum allocation the scratch space will allow */
+static size_t secp256k1_scratch_max_allocation(const secp256k1_callback* error_callback, const secp256k1_scratch* scratch, size_t n_objects);
+
+/** Returns a pointer into the most recently allocated frame, or NULL if there is insufficient available space */
+static void *secp256k1_scratch_alloc(const secp256k1_callback* error_callback, secp256k1_scratch* scratch, size_t n);
+
+#endif
diff --git a/crypto/secp256k1/libsecp256k1/src/scratch_impl.h b/crypto/secp256k1/libsecp256k1/src/scratch_impl.h
new file mode 100644
index 000000000..4cee70000
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/src/scratch_impl.h
@@ -0,0 +1,88 @@
+/**********************************************************************
+ * Copyright (c) 2017 Andrew Poelstra                                 *
+ * Distributed under the MIT software license, see the accompanying   *
+ * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
+ **********************************************************************/
+
+#ifndef _SECP256K1_SCRATCH_IMPL_H_
+#define _SECP256K1_SCRATCH_IMPL_H_
+
+#include "util.h"
+#include "scratch.h"
+
+static secp256k1_scratch* secp256k1_scratch_create(const secp256k1_callback* error_callback, size_t size) {
+    const size_t base_alloc = ((sizeof(secp256k1_scratch) + ALIGNMENT - 1) / ALIGNMENT) * ALIGNMENT;
+    void *alloc = checked_malloc(error_callback, base_alloc + size);
+    secp256k1_scratch* ret = (secp256k1_scratch *)alloc;
+    if (ret != NULL) {
+        memset(ret, 0, sizeof(*ret));
+        memcpy(ret->magic, "scratch", 8);
+        ret->data = (void *) ((char *) alloc + base_alloc);
+        ret->max_size = size;
+    }
+    return ret;
+}
+
+static void secp256k1_scratch_destroy(const secp256k1_callback* error_callback, secp256k1_scratch* scratch) {
+    if (scratch != NULL) {
+        VERIFY_CHECK(scratch->alloc_size == 0); /* all checkpoints should be applied */
+        if (memcmp(scratch->magic, "scratch", 8) != 0) {
+            secp256k1_callback_call(error_callback, "invalid scratch space");
+            return;
+        }
+        memset(scratch->magic, 0, sizeof(scratch->magic));
+        free(scratch);
+    }
+}
+
+static size_t secp256k1_scratch_checkpoint(const secp256k1_callback* error_callback, const secp256k1_scratch* scratch) {
+    if (memcmp(scratch->magic, "scratch", 8) != 0) {
+        secp256k1_callback_call(error_callback, "invalid scratch space");
+        return 0;
+    }
+    return scratch->alloc_size;
+}
+
+static void secp256k1_scratch_apply_checkpoint(const secp256k1_callback* error_callback, secp256k1_scratch* scratch, size_t checkpoint) {
+    if (memcmp(scratch->magic, "scratch", 8) != 0) {
+        secp256k1_callback_call(error_callback, "invalid scratch space");
+        return;
+    }
+    if (checkpoint > scratch->alloc_size) {
+        secp256k1_callback_call(error_callback, "invalid checkpoint");
+        return;
+    }
+    scratch->alloc_size = checkpoint;
+}
+
+static size_t secp256k1_scratch_max_allocation(const secp256k1_callback* error_callback, const secp256k1_scratch* scratch, size_t objects) {
+    if (memcmp(scratch->magic, "scratch", 8) != 0) {
+        secp256k1_callback_call(error_callback, "invalid scratch space");
+        return 0;
+    }
+    if (scratch->max_size - scratch->alloc_size <= objects * (ALIGNMENT - 1)) {
+        return 0;
+    }
+    return scratch->max_size - scratch->alloc_size - objects * (ALIGNMENT - 1);
+}
+
+static void *secp256k1_scratch_alloc(const secp256k1_callback* error_callback, secp256k1_scratch* scratch, size_t size) {
+    void *ret;
+    size = ROUND_TO_ALIGN(size);
+
+    if (memcmp(scratch->magic, "scratch", 8) != 0) {
+        secp256k1_callback_call(error_callback, "invalid scratch space");
+        return NULL;
+    }
+
+    if (size > scratch->max_size - scratch->alloc_size) {
+        return NULL;
+    }
+    ret = (void *) ((char *) scratch->data + scratch->alloc_size);
+    memset(ret, 0, size);
+    scratch->alloc_size += size;
+
+    return ret;
+}
+
+#endif
diff --git a/crypto/secp256k1/libsecp256k1/src/secp256k1.c b/crypto/secp256k1/libsecp256k1/src/secp256k1.c
old mode 100755
new mode 100644
index 7d637bfad..de66be578
--- a/crypto/secp256k1/libsecp256k1/src/secp256k1.c
+++ b/crypto/secp256k1/libsecp256k1/src/secp256k1.c
@@ -5,6 +5,7 @@
  **********************************************************************/
 
 #include "include/secp256k1.h"
+#include "include/secp256k1_preallocated.h"
 
 #include "util.h"
 #include "num_impl.h"
@@ -17,6 +18,11 @@
 #include "ecdsa_impl.h"
 #include "eckey_impl.h"
 #include "hash_impl.h"
+#include "scratch_impl.h"
+
+#if defined(VALGRIND)
+# include <valgrind/memcheck.h>
+#endif
 
 #define ARG_CHECK(cond) do { \
     if (EXPECT(!(cond), 0)) { \
@@ -25,43 +31,101 @@
     } \
 } while(0)
 
-static void default_illegal_callback_fn(const char* str, void* data) {
+#define ARG_CHECK_NO_RETURN(cond) do { \
+    if (EXPECT(!(cond), 0)) { \
+        secp256k1_callback_call(&ctx->illegal_callback, #cond); \
+    } \
+} while(0)
+
+#ifndef USE_EXTERNAL_DEFAULT_CALLBACKS
+#include <stdlib.h>
+#include <stdio.h>
+static void secp256k1_default_illegal_callback_fn(const char* str, void* data) {
+    (void)data;
     fprintf(stderr, "[libsecp256k1] illegal argument: %s\n", str);
     abort();
 }
+static void secp256k1_default_error_callback_fn(const char* str, void* data) {
+    (void)data;
+    fprintf(stderr, "[libsecp256k1] internal consistency check failed: %s\n", str);
+    abort();
+}
+#else
+void secp256k1_default_illegal_callback_fn(const char* str, void* data);
+void secp256k1_default_error_callback_fn(const char* str, void* data);
+#endif
 
 static const secp256k1_callback default_illegal_callback = {
-    default_illegal_callback_fn,
+    secp256k1_default_illegal_callback_fn,
     NULL
 };
 
-static void default_error_callback_fn(const char* str, void* data) {
-    fprintf(stderr, "[libsecp256k1] internal consistency check failed: %s\n", str);
-    abort();
-}
-
 static const secp256k1_callback default_error_callback = {
-    default_error_callback_fn,
+    secp256k1_default_error_callback_fn,
     NULL
 };
 
-
 struct secp256k1_context_struct {
     secp256k1_ecmult_context ecmult_ctx;
     secp256k1_ecmult_gen_context ecmult_gen_ctx;
     secp256k1_callback illegal_callback;
     secp256k1_callback error_callback;
+    int declassify;
 };
 
-secp256k1_context* secp256k1_context_create(unsigned int flags) {
-    secp256k1_context* ret = (secp256k1_context*)checked_malloc(&default_error_callback, sizeof(secp256k1_context));
+static const secp256k1_context secp256k1_context_no_precomp_ = {
+    { 0 },
+    { 0 },
+    { secp256k1_default_illegal_callback_fn, 0 },
+    { secp256k1_default_error_callback_fn, 0 },
+    0
+};
+const secp256k1_context *secp256k1_context_no_precomp = &secp256k1_context_no_precomp_;
+
+size_t secp256k1_context_preallocated_size(unsigned int flags) {
+    size_t ret = ROUND_TO_ALIGN(sizeof(secp256k1_context));
+
+    if (EXPECT((flags & SECP256K1_FLAGS_TYPE_MASK) != SECP256K1_FLAGS_TYPE_CONTEXT, 0)) {
+            secp256k1_callback_call(&default_illegal_callback,
+                                    "Invalid flags");
+            return 0;
+    }
+
+    if (flags & SECP256K1_FLAGS_BIT_CONTEXT_SIGN) {
+        ret += SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE;
+    }
+    if (flags & SECP256K1_FLAGS_BIT_CONTEXT_VERIFY) {
+        ret += SECP256K1_ECMULT_CONTEXT_PREALLOCATED_SIZE;
+    }
+    return ret;
+}
+
+size_t secp256k1_context_preallocated_clone_size(const secp256k1_context* ctx) {
+    size_t ret = ROUND_TO_ALIGN(sizeof(secp256k1_context));
+    VERIFY_CHECK(ctx != NULL);
+    if (secp256k1_ecmult_gen_context_is_built(&ctx->ecmult_gen_ctx)) {
+        ret += SECP256K1_ECMULT_GEN_CONTEXT_PREALLOCATED_SIZE;
+    }
+    if (secp256k1_ecmult_context_is_built(&ctx->ecmult_ctx)) {
+        ret += SECP256K1_ECMULT_CONTEXT_PREALLOCATED_SIZE;
+    }
+    return ret;
+}
+
+secp256k1_context* secp256k1_context_preallocated_create(void* prealloc, unsigned int flags) {
+    void* const base = prealloc;
+    size_t prealloc_size;
+    secp256k1_context* ret;
+
+    VERIFY_CHECK(prealloc != NULL);
+    prealloc_size = secp256k1_context_preallocated_size(flags);
+    ret = (secp256k1_context*)manual_alloc(&prealloc, sizeof(secp256k1_context), base, prealloc_size);
     ret->illegal_callback = default_illegal_callback;
     ret->error_callback = default_error_callback;
 
     if (EXPECT((flags & SECP256K1_FLAGS_TYPE_MASK) != SECP256K1_FLAGS_TYPE_CONTEXT, 0)) {
             secp256k1_callback_call(&ret->illegal_callback,
                                     "Invalid flags");
-            free(ret);
             return NULL;
     }
 
@@ -69,56 +133,116 @@ secp256k1_context* secp256k1_context_create(unsigned int flags) {
     secp256k1_ecmult_gen_context_init(&ret->ecmult_gen_ctx);
 
     if (flags & SECP256K1_FLAGS_BIT_CONTEXT_SIGN) {
-        secp256k1_ecmult_gen_context_build(&ret->ecmult_gen_ctx, &ret->error_callback);
+        secp256k1_ecmult_gen_context_build(&ret->ecmult_gen_ctx, &prealloc);
     }
     if (flags & SECP256K1_FLAGS_BIT_CONTEXT_VERIFY) {
-        secp256k1_ecmult_context_build(&ret->ecmult_ctx, &ret->error_callback);
+        secp256k1_ecmult_context_build(&ret->ecmult_ctx, &prealloc);
+    }
+    ret->declassify = !!(flags & SECP256K1_FLAGS_BIT_CONTEXT_DECLASSIFY);
+
+    return (secp256k1_context*) ret;
+}
+
+secp256k1_context* secp256k1_context_create(unsigned int flags) {
+    size_t const prealloc_size = secp256k1_context_preallocated_size(flags);
+    secp256k1_context* ctx = (secp256k1_context*)checked_malloc(&default_error_callback, prealloc_size);
+    if (EXPECT(secp256k1_context_preallocated_create(ctx, flags) == NULL, 0)) {
+        free(ctx);
+        return NULL;
     }
 
+    return ctx;
+}
+
+secp256k1_context* secp256k1_context_preallocated_clone(const secp256k1_context* ctx, void* prealloc) {
+    size_t prealloc_size;
+    secp256k1_context* ret;
+    VERIFY_CHECK(ctx != NULL);
+    ARG_CHECK(prealloc != NULL);
+
+    prealloc_size = secp256k1_context_preallocated_clone_size(ctx);
+    ret = (secp256k1_context*)prealloc;
+    memcpy(ret, ctx, prealloc_size);
+    secp256k1_ecmult_gen_context_finalize_memcpy(&ret->ecmult_gen_ctx, &ctx->ecmult_gen_ctx);
+    secp256k1_ecmult_context_finalize_memcpy(&ret->ecmult_ctx, &ctx->ecmult_ctx);
     return ret;
 }
 
 secp256k1_context* secp256k1_context_clone(const secp256k1_context* ctx) {
-    secp256k1_context* ret = (secp256k1_context*)checked_malloc(&ctx->error_callback, sizeof(secp256k1_context));
-    ret->illegal_callback = ctx->illegal_callback;
-    ret->error_callback = ctx->error_callback;
-    secp256k1_ecmult_context_clone(&ret->ecmult_ctx, &ctx->ecmult_ctx, &ctx->error_callback);
-    secp256k1_ecmult_gen_context_clone(&ret->ecmult_gen_ctx, &ctx->ecmult_gen_ctx, &ctx->error_callback);
+    secp256k1_context* ret;
+    size_t prealloc_size;
+
+    VERIFY_CHECK(ctx != NULL);
+    prealloc_size = secp256k1_context_preallocated_clone_size(ctx);
+    ret = (secp256k1_context*)checked_malloc(&ctx->error_callback, prealloc_size);
+    ret = secp256k1_context_preallocated_clone(ctx, ret);
     return ret;
 }
 
-void secp256k1_context_destroy(secp256k1_context* ctx) {
+void secp256k1_context_preallocated_destroy(secp256k1_context* ctx) {
+    ARG_CHECK_NO_RETURN(ctx != secp256k1_context_no_precomp);
     if (ctx != NULL) {
         secp256k1_ecmult_context_clear(&ctx->ecmult_ctx);
         secp256k1_ecmult_gen_context_clear(&ctx->ecmult_gen_ctx);
+    }
+}
 
+void secp256k1_context_destroy(secp256k1_context* ctx) {
+    if (ctx != NULL) {
+        secp256k1_context_preallocated_destroy(ctx);
         free(ctx);
     }
 }
 
 void secp256k1_context_set_illegal_callback(secp256k1_context* ctx, void (*fun)(const char* message, void* data), const void* data) {
+    ARG_CHECK_NO_RETURN(ctx != secp256k1_context_no_precomp);
     if (fun == NULL) {
-        fun = default_illegal_callback_fn;
+        fun = secp256k1_default_illegal_callback_fn;
     }
     ctx->illegal_callback.fn = fun;
     ctx->illegal_callback.data = data;
 }
 
 void secp256k1_context_set_error_callback(secp256k1_context* ctx, void (*fun)(const char* message, void* data), const void* data) {
+    ARG_CHECK_NO_RETURN(ctx != secp256k1_context_no_precomp);
     if (fun == NULL) {
-        fun = default_error_callback_fn;
+        fun = secp256k1_default_error_callback_fn;
     }
     ctx->error_callback.fn = fun;
     ctx->error_callback.data = data;
 }
 
+secp256k1_scratch_space* secp256k1_scratch_space_create(const secp256k1_context* ctx, size_t max_size) {
+    VERIFY_CHECK(ctx != NULL);
+    return secp256k1_scratch_create(&ctx->error_callback, max_size);
+}
+
+void secp256k1_scratch_space_destroy(const secp256k1_context *ctx, secp256k1_scratch_space* scratch) {
+    VERIFY_CHECK(ctx != NULL);
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+}
+
+/* Mark memory as no-longer-secret for the purpose of analysing constant-time behaviour
+ *  of the software. This is setup for use with valgrind but could be substituted with
+ *  the appropriate instrumentation for other analysis tools.
+ */
+static SECP256K1_INLINE void secp256k1_declassify(const secp256k1_context* ctx, void *p, size_t len) {
+#if defined(VALGRIND)
+    if (EXPECT(ctx->declassify,0)) VALGRIND_MAKE_MEM_DEFINED(p, len);
+#else
+    (void)ctx;
+    (void)p;
+    (void)len;
+#endif
+}
+
 static int secp256k1_pubkey_load(const secp256k1_context* ctx, secp256k1_ge* ge, const secp256k1_pubkey* pubkey) {
     if (sizeof(secp256k1_ge_storage) == 64) {
         /* When the secp256k1_ge_storage type is exactly 64 byte, use its
          * representation inside secp256k1_pubkey, as conversion is very fast.
          * Note that secp256k1_pubkey_save must use the same representation. */
         secp256k1_ge_storage s;
-        memcpy(&s, &pubkey->data[0], 64);
+        memcpy(&s, &pubkey->data[0], sizeof(s));
         secp256k1_ge_from_storage(ge, &s);
     } else {
         /* Otherwise, fall back to 32-byte big endian for X and Y. */
@@ -135,7 +259,7 @@ static void secp256k1_pubkey_save(secp256k1_pubkey* pubkey, secp256k1_ge* ge) {
     if (sizeof(secp256k1_ge_storage) == 64) {
         secp256k1_ge_storage s;
         secp256k1_ge_to_storage(&s, ge);
-        memcpy(&pubkey->data[0], &s, 64);
+        memcpy(&pubkey->data[0], &s, sizeof(s));
     } else {
         VERIFY_CHECK(!secp256k1_ge_is_infinity(ge));
         secp256k1_fe_normalize_var(&ge->x);
@@ -305,10 +429,15 @@ int secp256k1_ecdsa_verify(const secp256k1_context* ctx, const secp256k1_ecdsa_s
             secp256k1_ecdsa_sig_verify(&ctx->ecmult_ctx, &r, &s, &q, &m));
 }
 
+static SECP256K1_INLINE void buffer_append(unsigned char *buf, unsigned int *offset, const void *data, unsigned int len) {
+    memcpy(buf + *offset, data, len);
+    *offset += len;
+}
+
 static int nonce_function_rfc6979(unsigned char *nonce32, const unsigned char *msg32, const unsigned char *key32, const unsigned char *algo16, void *data, unsigned int counter) {
    unsigned char keydata[112];
-   int keylen = 64;
-   secp256k1_rfc6979_hmac_sha256_t rng;
+   unsigned int offset = 0;
+   secp256k1_rfc6979_hmac_sha256 rng;
    unsigned int i;
    /* We feed a byte array to the PRNG as input, consisting of:
     * - the private key (32 bytes) and message (32 bytes), see RFC 6979 3.2d.
@@ -318,17 +447,15 @@ static int nonce_function_rfc6979(unsigned char *nonce32, const unsigned char *m
     *  different argument mixtures to emulate each other and result in the same
     *  nonces.
     */
-   memcpy(keydata, key32, 32);
-   memcpy(keydata + 32, msg32, 32);
+   buffer_append(keydata, &offset, key32, 32);
+   buffer_append(keydata, &offset, msg32, 32);
    if (data != NULL) {
-       memcpy(keydata + 64, data, 32);
-       keylen = 96;
+       buffer_append(keydata, &offset, data, 32);
    }
    if (algo16 != NULL) {
-       memcpy(keydata + keylen, algo16, 16);
-       keylen += 16;
+       buffer_append(keydata, &offset, algo16, 16);
    }
-   secp256k1_rfc6979_hmac_sha256_initialize(&rng, keydata, keylen);
+   secp256k1_rfc6979_hmac_sha256_initialize(&rng, keydata, offset);
    memset(keydata, 0, sizeof(keydata));
    for (i = 0; i <= counter; i++) {
        secp256k1_rfc6979_hmac_sha256_generate(&rng, nonce32, 32);
@@ -344,7 +471,9 @@ int secp256k1_ecdsa_sign(const secp256k1_context* ctx, secp256k1_ecdsa_signature
     secp256k1_scalar r, s;
     secp256k1_scalar sec, non, msg;
     int ret = 0;
-    int overflow = 0;
+    int is_sec_valid;
+    unsigned char nonce32[32];
+    unsigned int count = 0;
     VERIFY_CHECK(ctx != NULL);
     ARG_CHECK(secp256k1_ecmult_gen_context_is_built(&ctx->ecmult_gen_ctx));
     ARG_CHECK(msg32 != NULL);
@@ -354,47 +483,50 @@ int secp256k1_ecdsa_sign(const secp256k1_context* ctx, secp256k1_ecdsa_signature
         noncefp = secp256k1_nonce_function_default;
     }
 
-    secp256k1_scalar_set_b32(&sec, seckey, &overflow);
     /* Fail if the secret key is invalid. */
-    if (!overflow && !secp256k1_scalar_is_zero(&sec)) {
-        unsigned char nonce32[32];
-        unsigned int count = 0;
-        secp256k1_scalar_set_b32(&msg, msg32, NULL);
-        while (1) {
-            ret = noncefp(nonce32, msg32, seckey, NULL, (void*)noncedata, count);
-            if (!ret) {
+    is_sec_valid = secp256k1_scalar_set_b32_seckey(&sec, seckey);
+    secp256k1_scalar_cmov(&sec, &secp256k1_scalar_one, !is_sec_valid);
+    secp256k1_scalar_set_b32(&msg, msg32, NULL);
+    while (1) {
+        int is_nonce_valid;
+        ret = !!noncefp(nonce32, msg32, seckey, NULL, (void*)noncedata, count);
+        if (!ret) {
+            break;
+        }
+        is_nonce_valid = secp256k1_scalar_set_b32_seckey(&non, nonce32);
+        /* The nonce is still secret here, but it being invalid is is less likely than 1:2^255. */
+        secp256k1_declassify(ctx, &is_nonce_valid, sizeof(is_nonce_valid));
+        if (is_nonce_valid) {
+            ret = secp256k1_ecdsa_sig_sign(&ctx->ecmult_gen_ctx, &r, &s, &sec, &msg, &non, NULL);
+            /* The final signature is no longer a secret, nor is the fact that we were successful or not. */
+            secp256k1_declassify(ctx, &ret, sizeof(ret));
+            if (ret) {
                 break;
             }
-            secp256k1_scalar_set_b32(&non, nonce32, &overflow);
-            if (!overflow && !secp256k1_scalar_is_zero(&non)) {
-                if (secp256k1_ecdsa_sig_sign(&ctx->ecmult_gen_ctx, &r, &s, &sec, &msg, &non, NULL)) {
-                    break;
-                }
-            }
-            count++;
         }
-        memset(nonce32, 0, 32);
-        secp256k1_scalar_clear(&msg);
-        secp256k1_scalar_clear(&non);
-        secp256k1_scalar_clear(&sec);
-    }
-    if (ret) {
-        secp256k1_ecdsa_signature_save(signature, &r, &s);
-    } else {
-        memset(signature, 0, sizeof(*signature));
+        count++;
     }
+    /* We don't want to declassify is_sec_valid and therefore the range of
+     * seckey. As a result is_sec_valid is included in ret only after ret was
+     * used as a branching variable. */
+    ret &= is_sec_valid;
+    memset(nonce32, 0, 32);
+    secp256k1_scalar_clear(&msg);
+    secp256k1_scalar_clear(&non);
+    secp256k1_scalar_clear(&sec);
+    secp256k1_scalar_cmov(&r, &secp256k1_scalar_zero, !ret);
+    secp256k1_scalar_cmov(&s, &secp256k1_scalar_zero, !ret);
+    secp256k1_ecdsa_signature_save(signature, &r, &s);
     return ret;
 }
 
 int secp256k1_ec_seckey_verify(const secp256k1_context* ctx, const unsigned char *seckey) {
     secp256k1_scalar sec;
     int ret;
-    int overflow;
     VERIFY_CHECK(ctx != NULL);
     ARG_CHECK(seckey != NULL);
 
-    secp256k1_scalar_set_b32(&sec, seckey, &overflow);
-    ret = !overflow && !secp256k1_scalar_is_zero(&sec);
+    ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);
     secp256k1_scalar_clear(&sec);
     return ret;
 }
@@ -403,7 +535,6 @@ int secp256k1_ec_pubkey_create(const secp256k1_context* ctx, secp256k1_pubkey *p
     secp256k1_gej pj;
     secp256k1_ge p;
     secp256k1_scalar sec;
-    int overflow;
     int ret = 0;
     VERIFY_CHECK(ctx != NULL);
     ARG_CHECK(pubkey != NULL);
@@ -411,18 +542,53 @@ int secp256k1_ec_pubkey_create(const secp256k1_context* ctx, secp256k1_pubkey *p
     ARG_CHECK(secp256k1_ecmult_gen_context_is_built(&ctx->ecmult_gen_ctx));
     ARG_CHECK(seckey != NULL);
 
-    secp256k1_scalar_set_b32(&sec, seckey, &overflow);
-    ret = (!overflow) & (!secp256k1_scalar_is_zero(&sec));
+    ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);
+    secp256k1_scalar_cmov(&sec, &secp256k1_scalar_one, !ret);
+
+    secp256k1_ecmult_gen(&ctx->ecmult_gen_ctx, &pj, &sec);
+    secp256k1_ge_set_gej(&p, &pj);
+    secp256k1_pubkey_save(pubkey, &p);
+    memczero(pubkey, sizeof(*pubkey), !ret);
+
+    secp256k1_scalar_clear(&sec);
+    return ret;
+}
+
+int secp256k1_ec_seckey_negate(const secp256k1_context* ctx, unsigned char *seckey) {
+    secp256k1_scalar sec;
+    int ret = 0;
+    VERIFY_CHECK(ctx != NULL);
+    ARG_CHECK(seckey != NULL);
+
+    ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);
+    secp256k1_scalar_cmov(&sec, &secp256k1_scalar_zero, !ret);
+    secp256k1_scalar_negate(&sec, &sec);
+    secp256k1_scalar_get_b32(seckey, &sec);
+
+    secp256k1_scalar_clear(&sec);
+    return ret;
+}
+
+int secp256k1_ec_privkey_negate(const secp256k1_context* ctx, unsigned char *seckey) {
+    return secp256k1_ec_seckey_negate(ctx, seckey);
+}
+
+int secp256k1_ec_pubkey_negate(const secp256k1_context* ctx, secp256k1_pubkey *pubkey) {
+    int ret = 0;
+    secp256k1_ge p;
+    VERIFY_CHECK(ctx != NULL);
+    ARG_CHECK(pubkey != NULL);
+
+    ret = secp256k1_pubkey_load(ctx, &p, pubkey);
+    memset(pubkey, 0, sizeof(*pubkey));
     if (ret) {
-        secp256k1_ecmult_gen(&ctx->ecmult_gen_ctx, &pj, &sec);
-        secp256k1_ge_set_gej(&p, &pj);
+        secp256k1_ge_neg(&p, &p);
         secp256k1_pubkey_save(pubkey, &p);
     }
-    secp256k1_scalar_clear(&sec);
     return ret;
 }
 
-int secp256k1_ec_privkey_tweak_add(const secp256k1_context* ctx, unsigned char *seckey, const unsigned char *tweak) {
+int secp256k1_ec_seckey_tweak_add(const secp256k1_context* ctx, unsigned char *seckey, const unsigned char *tweak) {
     secp256k1_scalar term;
     secp256k1_scalar sec;
     int ret = 0;
@@ -432,19 +598,21 @@ int secp256k1_ec_privkey_tweak_add(const secp256k1_context* ctx, unsigned char *
     ARG_CHECK(tweak != NULL);
 
     secp256k1_scalar_set_b32(&term, tweak, &overflow);
-    secp256k1_scalar_set_b32(&sec, seckey, NULL);
+    ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);
 
-    ret = !overflow && secp256k1_eckey_privkey_tweak_add(&sec, &term);
-    memset(seckey, 0, 32);
-    if (ret) {
-        secp256k1_scalar_get_b32(seckey, &sec);
-    }
+    ret &= (!overflow) & secp256k1_eckey_privkey_tweak_add(&sec, &term);
+    secp256k1_scalar_cmov(&sec, &secp256k1_scalar_zero, !ret);
+    secp256k1_scalar_get_b32(seckey, &sec);
 
     secp256k1_scalar_clear(&sec);
     secp256k1_scalar_clear(&term);
     return ret;
 }
 
+int secp256k1_ec_privkey_tweak_add(const secp256k1_context* ctx, unsigned char *seckey, const unsigned char *tweak) {
+    return secp256k1_ec_seckey_tweak_add(ctx, seckey, tweak);
+}
+
 int secp256k1_ec_pubkey_tweak_add(const secp256k1_context* ctx, secp256k1_pubkey *pubkey, const unsigned char *tweak) {
     secp256k1_ge p;
     secp256k1_scalar term;
@@ -469,7 +637,7 @@ int secp256k1_ec_pubkey_tweak_add(const secp256k1_context* ctx, secp256k1_pubkey
     return ret;
 }
 
-int secp256k1_ec_privkey_tweak_mul(const secp256k1_context* ctx, unsigned char *seckey, const unsigned char *tweak) {
+int secp256k1_ec_seckey_tweak_mul(const secp256k1_context* ctx, unsigned char *seckey, const unsigned char *tweak) {
     secp256k1_scalar factor;
     secp256k1_scalar sec;
     int ret = 0;
@@ -479,18 +647,20 @@ int secp256k1_ec_privkey_tweak_mul(const secp256k1_context* ctx, unsigned char *
     ARG_CHECK(tweak != NULL);
 
     secp256k1_scalar_set_b32(&factor, tweak, &overflow);
-    secp256k1_scalar_set_b32(&sec, seckey, NULL);
-    ret = !overflow && secp256k1_eckey_privkey_tweak_mul(&sec, &factor);
-    memset(seckey, 0, 32);
-    if (ret) {
-        secp256k1_scalar_get_b32(seckey, &sec);
-    }
+    ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);
+    ret &= (!overflow) & secp256k1_eckey_privkey_tweak_mul(&sec, &factor);
+    secp256k1_scalar_cmov(&sec, &secp256k1_scalar_zero, !ret);
+    secp256k1_scalar_get_b32(seckey, &sec);
 
     secp256k1_scalar_clear(&sec);
     secp256k1_scalar_clear(&factor);
     return ret;
 }
 
+int secp256k1_ec_privkey_tweak_mul(const secp256k1_context* ctx, unsigned char *seckey, const unsigned char *tweak) {
+    return secp256k1_ec_seckey_tweak_mul(ctx, seckey, tweak);
+}
+
 int secp256k1_ec_pubkey_tweak_mul(const secp256k1_context* ctx, secp256k1_pubkey *pubkey, const unsigned char *tweak) {
     secp256k1_ge p;
     secp256k1_scalar factor;
@@ -517,8 +687,9 @@ int secp256k1_ec_pubkey_tweak_mul(const secp256k1_context* ctx, secp256k1_pubkey
 
 int secp256k1_context_randomize(secp256k1_context* ctx, const unsigned char *seed32) {
     VERIFY_CHECK(ctx != NULL);
-    ARG_CHECK(secp256k1_ecmult_gen_context_is_built(&ctx->ecmult_gen_ctx));
-    secp256k1_ecmult_gen_blind(&ctx->ecmult_gen_ctx, seed32);
+    if (secp256k1_ecmult_gen_context_is_built(&ctx->ecmult_gen_ctx)) {
+        secp256k1_ecmult_gen_blind(&ctx->ecmult_gen_ctx, seed32);
+    }
     return 1;
 }
 
@@ -550,10 +721,6 @@ int secp256k1_ec_pubkey_combine(const secp256k1_context* ctx, secp256k1_pubkey *
 # include "modules/ecdh/main_impl.h"
 #endif
 
-#ifdef ENABLE_MODULE_SCHNORR
-# include "modules/schnorr/main_impl.h"
-#endif
-
 #ifdef ENABLE_MODULE_RECOVERY
 # include "modules/recovery/main_impl.h"
 #endif
diff --git a/crypto/secp256k1/libsecp256k1/src/testrand.h b/crypto/secp256k1/libsecp256k1/src/testrand.h
index f8efa93c7..f1f9be077 100644
--- a/crypto/secp256k1/libsecp256k1/src/testrand.h
+++ b/crypto/secp256k1/libsecp256k1/src/testrand.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_TESTRAND_H_
-#define _SECP256K1_TESTRAND_H_
+#ifndef SECP256K1_TESTRAND_H
+#define SECP256K1_TESTRAND_H
 
 #if defined HAVE_CONFIG_H
 #include "libsecp256k1-config.h"
@@ -35,4 +35,4 @@ static void secp256k1_rand256_test(unsigned char *b32);
 /** Generate pseudorandom bytes with long sequences of zero and one bits. */
 static void secp256k1_rand_bytes_test(unsigned char *bytes, size_t len);
 
-#endif
+#endif /* SECP256K1_TESTRAND_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/testrand_impl.h b/crypto/secp256k1/libsecp256k1/src/testrand_impl.h
index 15c7b9f12..30a91e529 100644
--- a/crypto/secp256k1/libsecp256k1/src/testrand_impl.h
+++ b/crypto/secp256k1/libsecp256k1/src/testrand_impl.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_TESTRAND_IMPL_H_
-#define _SECP256K1_TESTRAND_IMPL_H_
+#ifndef SECP256K1_TESTRAND_IMPL_H
+#define SECP256K1_TESTRAND_IMPL_H
 
 #include <stdint.h>
 #include <string.h>
@@ -13,7 +13,7 @@
 #include "testrand.h"
 #include "hash.h"
 
-static secp256k1_rfc6979_hmac_sha256_t secp256k1_test_rng;
+static secp256k1_rfc6979_hmac_sha256 secp256k1_test_rng;
 static uint32_t secp256k1_test_rng_precomputed[8];
 static int secp256k1_test_rng_precomputed_used = 8;
 static uint64_t secp256k1_test_rng_integer;
@@ -107,4 +107,4 @@ static void secp256k1_rand256_test(unsigned char *b32) {
     secp256k1_rand_bytes_test(b32, 32);
 }
 
-#endif
+#endif /* SECP256K1_TESTRAND_IMPL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/tests.c b/crypto/secp256k1/libsecp256k1/src/tests.c
index 9ae7d3028..324b60cf1 100644
--- a/crypto/secp256k1/libsecp256k1/src/tests.c
+++ b/crypto/secp256k1/libsecp256k1/src/tests.c
@@ -10,11 +10,13 @@
 
 #include <stdio.h>
 #include <stdlib.h>
+#include <string.h>
 
 #include <time.h>
 
 #include "secp256k1.c"
 #include "include/secp256k1.h"
+#include "include/secp256k1_preallocated.h"
 #include "testrand_impl.h"
 
 #ifdef ENABLE_OPENSSL_TESTS
@@ -22,6 +24,9 @@
 #include "openssl/ec.h"
 #include "openssl/ecdsa.h"
 #include "openssl/obj_mac.h"
+# if OPENSSL_VERSION_NUMBER < 0x10100000L
+void ECDSA_SIG_get0(const ECDSA_SIG *sig, const BIGNUM **pr, const BIGNUM **ps) {*pr = sig->r; *ps = sig->s;}
+# endif
 #endif
 
 #include "contrib/lax_der_parsing.c"
@@ -78,7 +83,9 @@ void random_field_element_magnitude(secp256k1_fe *fe) {
     secp256k1_fe_negate(&zero, &zero, 0);
     secp256k1_fe_mul_int(&zero, n - 1);
     secp256k1_fe_add(fe, &zero);
-    VERIFY_CHECK(fe->magnitude == n);
+#ifdef VERIFY
+    CHECK(fe->magnitude == n);
+#endif
 }
 
 void random_group_element_test(secp256k1_ge *ge) {
@@ -133,22 +140,55 @@ void random_scalar_order(secp256k1_scalar *num) {
     } while(1);
 }
 
-void run_context_tests(void) {
+void random_scalar_order_b32(unsigned char *b32) {
+    secp256k1_scalar num;
+    random_scalar_order(&num);
+    secp256k1_scalar_get_b32(b32, &num);
+}
+
+void run_context_tests(int use_prealloc) {
     secp256k1_pubkey pubkey;
+    secp256k1_pubkey zero_pubkey;
     secp256k1_ecdsa_signature sig;
     unsigned char ctmp[32];
     int32_t ecount;
     int32_t ecount2;
-    secp256k1_context *none = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
-    secp256k1_context *sign = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
-    secp256k1_context *vrfy = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);
-    secp256k1_context *both = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
+    secp256k1_context *none;
+    secp256k1_context *sign;
+    secp256k1_context *vrfy;
+    secp256k1_context *both;
+    void *none_prealloc = NULL;
+    void *sign_prealloc = NULL;
+    void *vrfy_prealloc = NULL;
+    void *both_prealloc = NULL;
 
     secp256k1_gej pubj;
     secp256k1_ge pub;
     secp256k1_scalar msg, key, nonce;
     secp256k1_scalar sigr, sigs;
 
+    if (use_prealloc) {
+        none_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_NONE));
+        sign_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN));
+        vrfy_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_VERIFY));
+        both_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY));
+        CHECK(none_prealloc != NULL);
+        CHECK(sign_prealloc != NULL);
+        CHECK(vrfy_prealloc != NULL);
+        CHECK(both_prealloc != NULL);
+        none = secp256k1_context_preallocated_create(none_prealloc, SECP256K1_CONTEXT_NONE);
+        sign = secp256k1_context_preallocated_create(sign_prealloc, SECP256K1_CONTEXT_SIGN);
+        vrfy = secp256k1_context_preallocated_create(vrfy_prealloc, SECP256K1_CONTEXT_VERIFY);
+        both = secp256k1_context_preallocated_create(both_prealloc, SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
+    } else {
+        none = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
+        sign = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
+        vrfy = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);
+        both = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
+    }
+
+    memset(&zero_pubkey, 0, sizeof(zero_pubkey));
+
     ecount = 0;
     ecount2 = 10;
     secp256k1_context_set_illegal_callback(vrfy, counting_illegal_callback_fn, &ecount);
@@ -156,14 +196,57 @@ void run_context_tests(void) {
     secp256k1_context_set_error_callback(sign, counting_illegal_callback_fn, NULL);
     CHECK(vrfy->error_callback.fn != sign->error_callback.fn);
 
+    /* check if sizes for cloning are consistent */
+    CHECK(secp256k1_context_preallocated_clone_size(none) == secp256k1_context_preallocated_size(SECP256K1_CONTEXT_NONE));
+    CHECK(secp256k1_context_preallocated_clone_size(sign) == secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN));
+    CHECK(secp256k1_context_preallocated_clone_size(vrfy) == secp256k1_context_preallocated_size(SECP256K1_CONTEXT_VERIFY));
+    CHECK(secp256k1_context_preallocated_clone_size(both) == secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY));
+
     /*** clone and destroy all of them to make sure cloning was complete ***/
     {
         secp256k1_context *ctx_tmp;
 
-        ctx_tmp = none; none = secp256k1_context_clone(none); secp256k1_context_destroy(ctx_tmp);
-        ctx_tmp = sign; sign = secp256k1_context_clone(sign); secp256k1_context_destroy(ctx_tmp);
-        ctx_tmp = vrfy; vrfy = secp256k1_context_clone(vrfy); secp256k1_context_destroy(ctx_tmp);
-        ctx_tmp = both; both = secp256k1_context_clone(both); secp256k1_context_destroy(ctx_tmp);
+        if (use_prealloc) {
+            /* clone into a non-preallocated context and then again into a new preallocated one. */
+            ctx_tmp = none; none = secp256k1_context_clone(none); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(none_prealloc); none_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_NONE)); CHECK(none_prealloc != NULL);
+            ctx_tmp = none; none = secp256k1_context_preallocated_clone(none, none_prealloc); secp256k1_context_destroy(ctx_tmp);
+
+            ctx_tmp = sign; sign = secp256k1_context_clone(sign); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(sign_prealloc); sign_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN)); CHECK(sign_prealloc != NULL);
+            ctx_tmp = sign; sign = secp256k1_context_preallocated_clone(sign, sign_prealloc); secp256k1_context_destroy(ctx_tmp);
+
+            ctx_tmp = vrfy; vrfy = secp256k1_context_clone(vrfy); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(vrfy_prealloc); vrfy_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_VERIFY)); CHECK(vrfy_prealloc != NULL);
+            ctx_tmp = vrfy; vrfy = secp256k1_context_preallocated_clone(vrfy, vrfy_prealloc); secp256k1_context_destroy(ctx_tmp);
+
+            ctx_tmp = both; both = secp256k1_context_clone(both); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(both_prealloc); both_prealloc = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)); CHECK(both_prealloc != NULL);
+            ctx_tmp = both; both = secp256k1_context_preallocated_clone(both, both_prealloc); secp256k1_context_destroy(ctx_tmp);
+        } else {
+            /* clone into a preallocated context and then again into a new non-preallocated one. */
+            void *prealloc_tmp;
+
+            prealloc_tmp = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_NONE)); CHECK(prealloc_tmp != NULL);
+            ctx_tmp = none; none = secp256k1_context_preallocated_clone(none, prealloc_tmp); secp256k1_context_destroy(ctx_tmp);
+            ctx_tmp = none; none = secp256k1_context_clone(none); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(prealloc_tmp);
+
+            prealloc_tmp = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN)); CHECK(prealloc_tmp != NULL);
+            ctx_tmp = sign; sign = secp256k1_context_preallocated_clone(sign, prealloc_tmp); secp256k1_context_destroy(ctx_tmp);
+            ctx_tmp = sign; sign = secp256k1_context_clone(sign); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(prealloc_tmp);
+
+            prealloc_tmp = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_VERIFY)); CHECK(prealloc_tmp != NULL);
+            ctx_tmp = vrfy; vrfy = secp256k1_context_preallocated_clone(vrfy, prealloc_tmp); secp256k1_context_destroy(ctx_tmp);
+            ctx_tmp = vrfy; vrfy = secp256k1_context_clone(vrfy); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(prealloc_tmp);
+
+            prealloc_tmp = malloc(secp256k1_context_preallocated_size(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)); CHECK(prealloc_tmp != NULL);
+            ctx_tmp = both; both = secp256k1_context_preallocated_clone(both, prealloc_tmp); secp256k1_context_destroy(ctx_tmp);
+            ctx_tmp = both; both = secp256k1_context_clone(both); secp256k1_context_preallocated_destroy(ctx_tmp);
+            free(prealloc_tmp);
+        }
     }
 
     /* Verify that the error callback makes it across the clone. */
@@ -201,19 +284,27 @@ void run_context_tests(void) {
     CHECK(ecount == 2);
     CHECK(secp256k1_ec_pubkey_tweak_mul(sign, &pubkey, ctmp) == 0);
     CHECK(ecount2 == 13);
-    CHECK(secp256k1_ec_pubkey_tweak_mul(vrfy, &pubkey, ctmp) == 1);
+    CHECK(secp256k1_ec_pubkey_negate(vrfy, &pubkey) == 1);
+    CHECK(ecount == 2);
+    CHECK(secp256k1_ec_pubkey_negate(sign, &pubkey) == 1);
     CHECK(ecount == 2);
-    CHECK(secp256k1_context_randomize(vrfy, ctmp) == 0);
+    CHECK(secp256k1_ec_pubkey_negate(sign, NULL) == 0);
+    CHECK(ecount2 == 14);
+    CHECK(secp256k1_ec_pubkey_negate(vrfy, &zero_pubkey) == 0);
+    CHECK(ecount == 3);
+    CHECK(secp256k1_ec_pubkey_tweak_mul(vrfy, &pubkey, ctmp) == 1);
     CHECK(ecount == 3);
+    CHECK(secp256k1_context_randomize(vrfy, ctmp) == 1);
+    CHECK(ecount == 3);
+    CHECK(secp256k1_context_randomize(vrfy, NULL) == 1);
+    CHECK(ecount == 3);
+    CHECK(secp256k1_context_randomize(sign, ctmp) == 1);
+    CHECK(ecount2 == 14);
     CHECK(secp256k1_context_randomize(sign, NULL) == 1);
-    CHECK(ecount2 == 13);
+    CHECK(ecount2 == 14);
     secp256k1_context_set_illegal_callback(vrfy, NULL, NULL);
     secp256k1_context_set_illegal_callback(sign, NULL, NULL);
 
-    /* This shouldn't leak memory, due to already-set tests. */
-    secp256k1_ecmult_gen_context_build(&sign->ecmult_gen_ctx, NULL);
-    secp256k1_ecmult_context_build(&vrfy->ecmult_ctx, NULL);
-
     /* obtain a working nonce */
     do {
         random_scalar_order_test(&nonce);
@@ -228,12 +319,96 @@ void run_context_tests(void) {
     CHECK(secp256k1_ecdsa_sig_verify(&both->ecmult_ctx, &sigr, &sigs, &pub, &msg));
 
     /* cleanup */
-    secp256k1_context_destroy(none);
-    secp256k1_context_destroy(sign);
-    secp256k1_context_destroy(vrfy);
-    secp256k1_context_destroy(both);
+    if (use_prealloc) {
+        secp256k1_context_preallocated_destroy(none);
+        secp256k1_context_preallocated_destroy(sign);
+        secp256k1_context_preallocated_destroy(vrfy);
+        secp256k1_context_preallocated_destroy(both);
+        free(none_prealloc);
+        free(sign_prealloc);
+        free(vrfy_prealloc);
+        free(both_prealloc);
+    } else {
+        secp256k1_context_destroy(none);
+        secp256k1_context_destroy(sign);
+        secp256k1_context_destroy(vrfy);
+        secp256k1_context_destroy(both);
+    }
     /* Defined as no-op. */
     secp256k1_context_destroy(NULL);
+    secp256k1_context_preallocated_destroy(NULL);
+
+}
+
+void run_scratch_tests(void) {
+    const size_t adj_alloc = ((500 + ALIGNMENT - 1) / ALIGNMENT) * ALIGNMENT;
+
+    int32_t ecount = 0;
+    size_t checkpoint;
+    size_t checkpoint_2;
+    secp256k1_context *none = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
+    secp256k1_scratch_space *scratch;
+    secp256k1_scratch_space local_scratch;
+
+    /* Test public API */
+    secp256k1_context_set_illegal_callback(none, counting_illegal_callback_fn, &ecount);
+    secp256k1_context_set_error_callback(none, counting_illegal_callback_fn, &ecount);
+
+    scratch = secp256k1_scratch_space_create(none, 1000);
+    CHECK(scratch != NULL);
+    CHECK(ecount == 0);
+
+    /* Test internal API */
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 0) == 1000);
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 1) == 1000 - (ALIGNMENT - 1));
+    CHECK(scratch->alloc_size == 0);
+    CHECK(scratch->alloc_size % ALIGNMENT == 0);
+
+    /* Allocating 500 bytes succeeds */
+    checkpoint = secp256k1_scratch_checkpoint(&none->error_callback, scratch);
+    CHECK(secp256k1_scratch_alloc(&none->error_callback, scratch, 500) != NULL);
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 0) == 1000 - adj_alloc);
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 1) == 1000 - adj_alloc - (ALIGNMENT - 1));
+    CHECK(scratch->alloc_size != 0);
+    CHECK(scratch->alloc_size % ALIGNMENT == 0);
+
+    /* Allocating another 500 bytes fails */
+    CHECK(secp256k1_scratch_alloc(&none->error_callback, scratch, 500) == NULL);
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 0) == 1000 - adj_alloc);
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 1) == 1000 - adj_alloc - (ALIGNMENT - 1));
+    CHECK(scratch->alloc_size != 0);
+    CHECK(scratch->alloc_size % ALIGNMENT == 0);
+
+    /* ...but it succeeds once we apply the checkpoint to undo it */
+    secp256k1_scratch_apply_checkpoint(&none->error_callback, scratch, checkpoint);
+    CHECK(scratch->alloc_size == 0);
+    CHECK(secp256k1_scratch_max_allocation(&none->error_callback, scratch, 0) == 1000);
+    CHECK(secp256k1_scratch_alloc(&none->error_callback, scratch, 500) != NULL);
+    CHECK(scratch->alloc_size != 0);
+
+    /* try to apply a bad checkpoint */
+    checkpoint_2 = secp256k1_scratch_checkpoint(&none->error_callback, scratch);
+    secp256k1_scratch_apply_checkpoint(&none->error_callback, scratch, checkpoint);
+    CHECK(ecount == 0);
+    secp256k1_scratch_apply_checkpoint(&none->error_callback, scratch, checkpoint_2); /* checkpoint_2 is after checkpoint */
+    CHECK(ecount == 1);
+    secp256k1_scratch_apply_checkpoint(&none->error_callback, scratch, (size_t) -1); /* this is just wildly invalid */
+    CHECK(ecount == 2);
+
+    /* try to use badly initialized scratch space */
+    secp256k1_scratch_space_destroy(none, scratch);
+    memset(&local_scratch, 0, sizeof(local_scratch));
+    scratch = &local_scratch;
+    CHECK(!secp256k1_scratch_max_allocation(&none->error_callback, scratch, 0));
+    CHECK(ecount == 3);
+    CHECK(secp256k1_scratch_alloc(&none->error_callback, scratch, 500) == NULL);
+    CHECK(ecount == 4);
+    secp256k1_scratch_space_destroy(none, scratch);
+    CHECK(ecount == 5);
+
+    /* cleanup */
+    secp256k1_scratch_space_destroy(none, NULL); /* no-op */
+    secp256k1_context_destroy(none);
 }
 
 /***** HASH TESTS *****/
@@ -258,7 +433,7 @@ void run_sha256_tests(void) {
     int i;
     for (i = 0; i < 8; i++) {
         unsigned char out[32];
-        secp256k1_sha256_t hasher;
+        secp256k1_sha256 hasher;
         secp256k1_sha256_initialize(&hasher);
         secp256k1_sha256_write(&hasher, (const unsigned char*)(inputs[i]), strlen(inputs[i]));
         secp256k1_sha256_finalize(&hasher, out);
@@ -301,7 +476,7 @@ void run_hmac_sha256_tests(void) {
     };
     int i;
     for (i = 0; i < 6; i++) {
-        secp256k1_hmac_sha256_t hasher;
+        secp256k1_hmac_sha256 hasher;
         unsigned char out[32];
         secp256k1_hmac_sha256_initialize(&hasher, (const unsigned char*)(keys[i]), strlen(keys[i]));
         secp256k1_hmac_sha256_write(&hasher, (const unsigned char*)(inputs[i]), strlen(inputs[i]));
@@ -333,7 +508,7 @@ void run_rfc6979_hmac_sha256_tests(void) {
         {0x75, 0x97, 0x88, 0x7c, 0xbd, 0x76, 0x32, 0x1f, 0x32, 0xe3, 0x04, 0x40, 0x67, 0x9a, 0x22, 0xcf, 0x7f, 0x8d, 0x9d, 0x2e, 0xac, 0x39, 0x0e, 0x58, 0x1f, 0xea, 0x09, 0x1c, 0xe2, 0x02, 0xba, 0x94}
     };
 
-    secp256k1_rfc6979_hmac_sha256_t rng;
+    secp256k1_rfc6979_hmac_sha256 rng;
     unsigned char out[32];
     int i;
 
@@ -908,11 +1083,31 @@ void scalar_test(void) {
 
 }
 
+void run_scalar_set_b32_seckey_tests(void) {
+    unsigned char b32[32];
+    secp256k1_scalar s1;
+    secp256k1_scalar s2;
+
+    /* Usually set_b32 and set_b32_seckey give the same result */
+    random_scalar_order_b32(b32);
+    secp256k1_scalar_set_b32(&s1, b32, NULL);
+    CHECK(secp256k1_scalar_set_b32_seckey(&s2, b32) == 1);
+    CHECK(secp256k1_scalar_eq(&s1, &s2) == 1);
+
+    memset(b32, 0, sizeof(b32));
+    CHECK(secp256k1_scalar_set_b32_seckey(&s2, b32) == 0);
+    memset(b32, 0xFF, sizeof(b32));
+    CHECK(secp256k1_scalar_set_b32_seckey(&s2, b32) == 0);
+}
+
 void run_scalar_tests(void) {
     int i;
     for (i = 0; i < 128 * count; i++) {
         scalar_test();
     }
+    for (i = 0; i < count; i++) {
+        run_scalar_set_b32_seckey_tests();
+    }
 
     {
         /* (-1)+1 should be zero. */
@@ -928,16 +1123,43 @@ void run_scalar_tests(void) {
 
 #ifndef USE_NUM_NONE
     {
-        /* A scalar with value of the curve order should be 0. */
+        /* Test secp256k1_scalar_set_b32 boundary conditions */
         secp256k1_num order;
-        secp256k1_scalar zero;
+        secp256k1_scalar scalar;
         unsigned char bin[32];
+        unsigned char bin_tmp[32];
         int overflow = 0;
+        /* 2^256-1 - order */
+        static const secp256k1_scalar all_ones_minus_order = SECP256K1_SCALAR_CONST(
+            0x00000000UL, 0x00000000UL, 0x00000000UL, 0x00000001UL,
+            0x45512319UL, 0x50B75FC4UL, 0x402DA173UL, 0x2FC9BEBEUL
+        );
+
+        /* A scalar set to 0s should be 0. */
+        memset(bin, 0, 32);
+        secp256k1_scalar_set_b32(&scalar, bin, &overflow);
+        CHECK(overflow == 0);
+        CHECK(secp256k1_scalar_is_zero(&scalar));
+
+        /* A scalar with value of the curve order should be 0. */
         secp256k1_scalar_order_get_num(&order);
         secp256k1_num_get_bin(bin, 32, &order);
-        secp256k1_scalar_set_b32(&zero, bin, &overflow);
+        secp256k1_scalar_set_b32(&scalar, bin, &overflow);
+        CHECK(overflow == 1);
+        CHECK(secp256k1_scalar_is_zero(&scalar));
+
+        /* A scalar with value of the curve order minus one should not overflow. */
+        bin[31] -= 1;
+        secp256k1_scalar_set_b32(&scalar, bin, &overflow);
+        CHECK(overflow == 0);
+        secp256k1_scalar_get_b32(bin_tmp, &scalar);
+        CHECK(memcmp(bin, bin_tmp, 32) == 0);
+
+        /* A scalar set to all 1s should overflow. */
+        memset(bin, 0xFF, 32);
+        secp256k1_scalar_set_b32(&scalar, bin, &overflow);
         CHECK(overflow == 1);
-        CHECK(secp256k1_scalar_is_zero(&zero));
+        CHECK(secp256k1_scalar_eq(&scalar, &all_ones_minus_order));
     }
 #endif
 
@@ -1652,24 +1874,32 @@ void run_field_misc(void) {
         /* Test fe conditional move; z is not normalized here. */
         q = x;
         secp256k1_fe_cmov(&x, &z, 0);
-        VERIFY_CHECK(!x.normalized && x.magnitude == z.magnitude);
+#ifdef VERIFY
+        CHECK(x.normalized && x.magnitude == 1);
+#endif
         secp256k1_fe_cmov(&x, &x, 1);
         CHECK(fe_memcmp(&x, &z) != 0);
         CHECK(fe_memcmp(&x, &q) == 0);
         secp256k1_fe_cmov(&q, &z, 1);
-        VERIFY_CHECK(!q.normalized && q.magnitude == z.magnitude);
+#ifdef VERIFY
+        CHECK(!q.normalized && q.magnitude == z.magnitude);
+#endif
         CHECK(fe_memcmp(&q, &z) == 0);
         secp256k1_fe_normalize_var(&x);
         secp256k1_fe_normalize_var(&z);
         CHECK(!secp256k1_fe_equal_var(&x, &z));
         secp256k1_fe_normalize_var(&q);
         secp256k1_fe_cmov(&q, &z, (i&1));
-        VERIFY_CHECK(q.normalized && q.magnitude == 1);
+#ifdef VERIFY
+        CHECK(q.normalized && q.magnitude == 1);
+#endif
         for (j = 0; j < 6; j++) {
             secp256k1_fe_negate(&z, &z, j+1);
             secp256k1_fe_normalize_var(&q);
             secp256k1_fe_cmov(&q, &z, (j&1));
-            VERIFY_CHECK(!q.normalized && q.magnitude == (j+2));
+#ifdef VERIFY
+            CHECK((q.normalized != (j&1)) && q.magnitude == ((j&1) ? z.magnitude : 1));
+#endif
         }
         secp256k1_fe_normalize_var(&z);
         /* Test storage conversion and conditional moves. */
@@ -1879,9 +2109,9 @@ void test_ge(void) {
      *
      * When the endomorphism code is compiled in, p5 = lambda*p1 and p6 = lambda^2*p1 are added as well.
      */
-    secp256k1_ge *ge = (secp256k1_ge *)malloc(sizeof(secp256k1_ge) * (1 + 4 * runs));
-    secp256k1_gej *gej = (secp256k1_gej *)malloc(sizeof(secp256k1_gej) * (1 + 4 * runs));
-    secp256k1_fe *zinv = (secp256k1_fe *)malloc(sizeof(secp256k1_fe) * (1 + 4 * runs));
+    secp256k1_ge *ge = (secp256k1_ge *)checked_malloc(&ctx->error_callback, sizeof(secp256k1_ge) * (1 + 4 * runs));
+    secp256k1_gej *gej = (secp256k1_gej *)checked_malloc(&ctx->error_callback, sizeof(secp256k1_gej) * (1 + 4 * runs));
+    secp256k1_fe *zinv = (secp256k1_fe *)checked_malloc(&ctx->error_callback, sizeof(secp256k1_fe) * (1 + 4 * runs));
     secp256k1_fe zf;
     secp256k1_fe zfi2, zfi3;
 
@@ -1919,7 +2149,7 @@ void test_ge(void) {
 
     /* Compute z inverses. */
     {
-        secp256k1_fe *zs = malloc(sizeof(secp256k1_fe) * (1 + 4 * runs));
+        secp256k1_fe *zs = checked_malloc(&ctx->error_callback, sizeof(secp256k1_fe) * (1 + 4 * runs));
         for (i = 0; i < 4 * runs + 1; i++) {
             if (i == 0) {
                 /* The point at infinity does not have a meaningful z inverse. Any should do. */
@@ -2020,7 +2250,7 @@ void test_ge(void) {
     /* Test adding all points together in random order equals infinity. */
     {
         secp256k1_gej sum = SECP256K1_GEJ_CONST_INFINITY;
-        secp256k1_gej *gej_shuffled = (secp256k1_gej *)malloc((4 * runs + 1) * sizeof(secp256k1_gej));
+        secp256k1_gej *gej_shuffled = (secp256k1_gej *)checked_malloc(&ctx->error_callback, (4 * runs + 1) * sizeof(secp256k1_gej));
         for (i = 0; i < 4 * runs + 1; i++) {
             gej_shuffled[i] = gej[i];
         }
@@ -2041,29 +2271,41 @@ void test_ge(void) {
 
     /* Test batch gej -> ge conversion with and without known z ratios. */
     {
-        secp256k1_fe *zr = (secp256k1_fe *)malloc((4 * runs + 1) * sizeof(secp256k1_fe));
-        secp256k1_ge *ge_set_table = (secp256k1_ge *)malloc((4 * runs + 1) * sizeof(secp256k1_ge));
-        secp256k1_ge *ge_set_all = (secp256k1_ge *)malloc((4 * runs + 1) * sizeof(secp256k1_ge));
+        secp256k1_fe *zr = (secp256k1_fe *)checked_malloc(&ctx->error_callback, (4 * runs + 1) * sizeof(secp256k1_fe));
+        secp256k1_ge *ge_set_all = (secp256k1_ge *)checked_malloc(&ctx->error_callback, (4 * runs + 1) * sizeof(secp256k1_ge));
         for (i = 0; i < 4 * runs + 1; i++) {
             /* Compute gej[i + 1].z / gez[i].z (with gej[n].z taken to be 1). */
             if (i < 4 * runs) {
                 secp256k1_fe_mul(&zr[i + 1], &zinv[i], &gej[i + 1].z);
             }
         }
-        secp256k1_ge_set_table_gej_var(ge_set_table, gej, zr, 4 * runs + 1);
-        secp256k1_ge_set_all_gej_var(ge_set_all, gej, 4 * runs + 1, &ctx->error_callback);
+        secp256k1_ge_set_all_gej_var(ge_set_all, gej, 4 * runs + 1);
         for (i = 0; i < 4 * runs + 1; i++) {
             secp256k1_fe s;
             random_fe_non_zero(&s);
             secp256k1_gej_rescale(&gej[i], &s);
-            ge_equals_gej(&ge_set_table[i], &gej[i]);
             ge_equals_gej(&ge_set_all[i], &gej[i]);
         }
-        free(ge_set_table);
         free(ge_set_all);
         free(zr);
     }
 
+    /* Test batch gej -> ge conversion with many infinities. */
+    for (i = 0; i < 4 * runs + 1; i++) {
+        random_group_element_test(&ge[i]);
+        /* randomly set half the points to infinity */
+        if(secp256k1_fe_is_odd(&ge[i].x)) {
+            secp256k1_ge_set_infinity(&ge[i]);
+        }
+        secp256k1_gej_set_ge(&gej[i], &ge[i]);
+    }
+    /* batch invert */
+    secp256k1_ge_set_all_gej_var(ge, gej, 4 * runs + 1);
+    /* check result */
+    for (i = 0; i < 4 * runs + 1; i++) {
+        ge_equals_gej(&ge[i], &gej[i]);
+    }
+
     free(ge);
     free(gej);
     free(zinv);
@@ -2393,7 +2635,7 @@ void ecmult_const_random_mult(void) {
         0xb84e4e1b, 0xfb77e21f, 0x96baae2a, 0x63dec956
     );
     secp256k1_gej b;
-    secp256k1_ecmult_const(&b, &a, &xn);
+    secp256k1_ecmult_const(&b, &a, &xn, 256);
 
     CHECK(secp256k1_ge_is_valid_var(&a));
     ge_equals_gej(&expected_b, &b);
@@ -2409,12 +2651,12 @@ void ecmult_const_commutativity(void) {
     random_scalar_order_test(&a);
     random_scalar_order_test(&b);
 
-    secp256k1_ecmult_const(&res1, &secp256k1_ge_const_g, &a);
-    secp256k1_ecmult_const(&res2, &secp256k1_ge_const_g, &b);
+    secp256k1_ecmult_const(&res1, &secp256k1_ge_const_g, &a, 256);
+    secp256k1_ecmult_const(&res2, &secp256k1_ge_const_g, &b, 256);
     secp256k1_ge_set_gej(&mid1, &res1);
     secp256k1_ge_set_gej(&mid2, &res2);
-    secp256k1_ecmult_const(&res1, &mid1, &b);
-    secp256k1_ecmult_const(&res2, &mid2, &a);
+    secp256k1_ecmult_const(&res1, &mid1, &b, 256);
+    secp256k1_ecmult_const(&res2, &mid2, &a, 256);
     secp256k1_ge_set_gej(&mid1, &res1);
     secp256k1_ge_set_gej(&mid2, &res2);
     ge_equals_ge(&mid1, &mid2);
@@ -2430,13 +2672,13 @@ void ecmult_const_mult_zero_one(void) {
     secp256k1_scalar_negate(&negone, &one);
 
     random_group_element_test(&point);
-    secp256k1_ecmult_const(&res1, &point, &zero);
+    secp256k1_ecmult_const(&res1, &point, &zero, 3);
     secp256k1_ge_set_gej(&res2, &res1);
     CHECK(secp256k1_ge_is_infinity(&res2));
-    secp256k1_ecmult_const(&res1, &point, &one);
+    secp256k1_ecmult_const(&res1, &point, &one, 2);
     secp256k1_ge_set_gej(&res2, &res1);
     ge_equals_ge(&res2, &point);
-    secp256k1_ecmult_const(&res1, &point, &negone);
+    secp256k1_ecmult_const(&res1, &point, &negone, 256);
     secp256k1_gej_neg(&res1, &res1);
     secp256k1_ge_set_gej(&res2, &res1);
     ge_equals_ge(&res2, &point);
@@ -2462,7 +2704,7 @@ void ecmult_const_chain_multiply(void) {
     for (i = 0; i < 100; ++i) {
         secp256k1_ge tmp;
         secp256k1_ge_set_gej(&tmp, &point);
-        secp256k1_ecmult_const(&point, &tmp, &scalar);
+        secp256k1_ecmult_const(&point, &tmp, &scalar, 256);
     }
     secp256k1_ge_set_gej(&res, &point);
     ge_equals_gej(&res, &expected_point);
@@ -2475,6 +2717,476 @@ void run_ecmult_const_tests(void) {
     ecmult_const_chain_multiply();
 }
 
+typedef struct {
+    secp256k1_scalar *sc;
+    secp256k1_ge *pt;
+} ecmult_multi_data;
+
+static int ecmult_multi_callback(secp256k1_scalar *sc, secp256k1_ge *pt, size_t idx, void *cbdata) {
+    ecmult_multi_data *data = (ecmult_multi_data*) cbdata;
+    *sc = data->sc[idx];
+    *pt = data->pt[idx];
+    return 1;
+}
+
+static int ecmult_multi_false_callback(secp256k1_scalar *sc, secp256k1_ge *pt, size_t idx, void *cbdata) {
+    (void)sc;
+    (void)pt;
+    (void)idx;
+    (void)cbdata;
+    return 0;
+}
+
+void test_ecmult_multi(secp256k1_scratch *scratch, secp256k1_ecmult_multi_func ecmult_multi) {
+    int ncount;
+    secp256k1_scalar szero;
+    secp256k1_scalar sc[32];
+    secp256k1_ge pt[32];
+    secp256k1_gej r;
+    secp256k1_gej r2;
+    ecmult_multi_data data;
+
+    data.sc = sc;
+    data.pt = pt;
+    secp256k1_scalar_set_int(&szero, 0);
+
+    /* No points to multiply */
+    CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, NULL, ecmult_multi_callback, &data, 0));
+
+    /* Check 1- and 2-point multiplies against ecmult */
+    for (ncount = 0; ncount < count; ncount++) {
+        secp256k1_ge ptg;
+        secp256k1_gej ptgj;
+        random_scalar_order(&sc[0]);
+        random_scalar_order(&sc[1]);
+
+        random_group_element_test(&ptg);
+        secp256k1_gej_set_ge(&ptgj, &ptg);
+        pt[0] = ptg;
+        pt[1] = secp256k1_ge_const_g;
+
+        /* only G scalar */
+        secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &ptgj, &szero, &sc[0]);
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &sc[0], ecmult_multi_callback, &data, 0));
+        secp256k1_gej_neg(&r2, &r2);
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+
+        /* 1-point */
+        secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &ptgj, &sc[0], &szero);
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 1));
+        secp256k1_gej_neg(&r2, &r2);
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+
+        /* Try to multiply 1 point, but callback returns false */
+        CHECK(!ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_false_callback, &data, 1));
+
+        /* 2-point */
+        secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &ptgj, &sc[0], &sc[1]);
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 2));
+        secp256k1_gej_neg(&r2, &r2);
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+
+        /* 2-point with G scalar */
+        secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &ptgj, &sc[0], &sc[1]);
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &sc[1], ecmult_multi_callback, &data, 1));
+        secp256k1_gej_neg(&r2, &r2);
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+    }
+
+    /* Check infinite outputs of various forms */
+    for (ncount = 0; ncount < count; ncount++) {
+        secp256k1_ge ptg;
+        size_t i, j;
+        size_t sizes[] = { 2, 10, 32 };
+
+        for (j = 0; j < 3; j++) {
+            for (i = 0; i < 32; i++) {
+                random_scalar_order(&sc[i]);
+                secp256k1_ge_set_infinity(&pt[i]);
+            }
+            CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, sizes[j]));
+            CHECK(secp256k1_gej_is_infinity(&r));
+        }
+
+        for (j = 0; j < 3; j++) {
+            for (i = 0; i < 32; i++) {
+                random_group_element_test(&ptg);
+                pt[i] = ptg;
+                secp256k1_scalar_set_int(&sc[i], 0);
+            }
+            CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, sizes[j]));
+            CHECK(secp256k1_gej_is_infinity(&r));
+        }
+
+        for (j = 0; j < 3; j++) {
+            random_group_element_test(&ptg);
+            for (i = 0; i < 16; i++) {
+                random_scalar_order(&sc[2*i]);
+                secp256k1_scalar_negate(&sc[2*i + 1], &sc[2*i]);
+                pt[2 * i] = ptg;
+                pt[2 * i + 1] = ptg;
+            }
+
+            CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, sizes[j]));
+            CHECK(secp256k1_gej_is_infinity(&r));
+
+            random_scalar_order(&sc[0]);
+            for (i = 0; i < 16; i++) {
+                random_group_element_test(&ptg);
+
+                sc[2*i] = sc[0];
+                sc[2*i+1] = sc[0];
+                pt[2 * i] = ptg;
+                secp256k1_ge_neg(&pt[2*i+1], &pt[2*i]);
+            }
+
+            CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, sizes[j]));
+            CHECK(secp256k1_gej_is_infinity(&r));
+        }
+
+        random_group_element_test(&ptg);
+        secp256k1_scalar_set_int(&sc[0], 0);
+        pt[0] = ptg;
+        for (i = 1; i < 32; i++) {
+            pt[i] = ptg;
+
+            random_scalar_order(&sc[i]);
+            secp256k1_scalar_add(&sc[0], &sc[0], &sc[i]);
+            secp256k1_scalar_negate(&sc[i], &sc[i]);
+        }
+
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 32));
+        CHECK(secp256k1_gej_is_infinity(&r));
+    }
+
+    /* Check random points, constant scalar */
+    for (ncount = 0; ncount < count; ncount++) {
+        size_t i;
+        secp256k1_gej_set_infinity(&r);
+
+        random_scalar_order(&sc[0]);
+        for (i = 0; i < 20; i++) {
+            secp256k1_ge ptg;
+            sc[i] = sc[0];
+            random_group_element_test(&ptg);
+            pt[i] = ptg;
+            secp256k1_gej_add_ge_var(&r, &r, &pt[i], NULL);
+        }
+
+        secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &r, &sc[0], &szero);
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 20));
+        secp256k1_gej_neg(&r2, &r2);
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+    }
+
+    /* Check random scalars, constant point */
+    for (ncount = 0; ncount < count; ncount++) {
+        size_t i;
+        secp256k1_ge ptg;
+        secp256k1_gej p0j;
+        secp256k1_scalar rs;
+        secp256k1_scalar_set_int(&rs, 0);
+
+        random_group_element_test(&ptg);
+        for (i = 0; i < 20; i++) {
+            random_scalar_order(&sc[i]);
+            pt[i] = ptg;
+            secp256k1_scalar_add(&rs, &rs, &sc[i]);
+        }
+
+        secp256k1_gej_set_ge(&p0j, &pt[0]);
+        secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &p0j, &rs, &szero);
+        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 20));
+        secp256k1_gej_neg(&r2, &r2);
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+    }
+
+    /* Sanity check that zero scalars don't cause problems */
+    for (ncount = 0; ncount < 20; ncount++) {
+        random_scalar_order(&sc[ncount]);
+        random_group_element_test(&pt[ncount]);
+    }
+
+    secp256k1_scalar_clear(&sc[0]);
+    CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 20));
+    secp256k1_scalar_clear(&sc[1]);
+    secp256k1_scalar_clear(&sc[2]);
+    secp256k1_scalar_clear(&sc[3]);
+    secp256k1_scalar_clear(&sc[4]);
+    CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 6));
+    CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &szero, ecmult_multi_callback, &data, 5));
+    CHECK(secp256k1_gej_is_infinity(&r));
+
+    /* Run through s0*(t0*P) + s1*(t1*P) exhaustively for many small values of s0, s1, t0, t1 */
+    {
+        const size_t TOP = 8;
+        size_t s0i, s1i;
+        size_t t0i, t1i;
+        secp256k1_ge ptg;
+        secp256k1_gej ptgj;
+
+        random_group_element_test(&ptg);
+        secp256k1_gej_set_ge(&ptgj, &ptg);
+
+        for(t0i = 0; t0i < TOP; t0i++) {
+            for(t1i = 0; t1i < TOP; t1i++) {
+                secp256k1_gej t0p, t1p;
+                secp256k1_scalar t0, t1;
+
+                secp256k1_scalar_set_int(&t0, (t0i + 1) / 2);
+                secp256k1_scalar_cond_negate(&t0, t0i & 1);
+                secp256k1_scalar_set_int(&t1, (t1i + 1) / 2);
+                secp256k1_scalar_cond_negate(&t1, t1i & 1);
+
+                secp256k1_ecmult(&ctx->ecmult_ctx, &t0p, &ptgj, &t0, &szero);
+                secp256k1_ecmult(&ctx->ecmult_ctx, &t1p, &ptgj, &t1, &szero);
+
+                for(s0i = 0; s0i < TOP; s0i++) {
+                    for(s1i = 0; s1i < TOP; s1i++) {
+                        secp256k1_scalar tmp1, tmp2;
+                        secp256k1_gej expected, actual;
+
+                        secp256k1_ge_set_gej(&pt[0], &t0p);
+                        secp256k1_ge_set_gej(&pt[1], &t1p);
+
+                        secp256k1_scalar_set_int(&sc[0], (s0i + 1) / 2);
+                        secp256k1_scalar_cond_negate(&sc[0], s0i & 1);
+                        secp256k1_scalar_set_int(&sc[1], (s1i + 1) / 2);
+                        secp256k1_scalar_cond_negate(&sc[1], s1i & 1);
+
+                        secp256k1_scalar_mul(&tmp1, &t0, &sc[0]);
+                        secp256k1_scalar_mul(&tmp2, &t1, &sc[1]);
+                        secp256k1_scalar_add(&tmp1, &tmp1, &tmp2);
+
+                        secp256k1_ecmult(&ctx->ecmult_ctx, &expected, &ptgj, &tmp1, &szero);
+                        CHECK(ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &actual, &szero, ecmult_multi_callback, &data, 2));
+                        secp256k1_gej_neg(&expected, &expected);
+                        secp256k1_gej_add_var(&actual, &actual, &expected, NULL);
+                        CHECK(secp256k1_gej_is_infinity(&actual));
+                    }
+                }
+            }
+        }
+    }
+}
+
+void test_ecmult_multi_batch_single(secp256k1_ecmult_multi_func ecmult_multi) {
+    secp256k1_scalar szero;
+    secp256k1_scalar sc[32];
+    secp256k1_ge pt[32];
+    secp256k1_gej r;
+    ecmult_multi_data data;
+    secp256k1_scratch *scratch_empty;
+
+    data.sc = sc;
+    data.pt = pt;
+    secp256k1_scalar_set_int(&szero, 0);
+
+    /* Try to multiply 1 point, but scratch space is empty.*/
+    scratch_empty = secp256k1_scratch_create(&ctx->error_callback, 0);
+    CHECK(!ecmult_multi(&ctx->error_callback, &ctx->ecmult_ctx, scratch_empty, &r, &szero, ecmult_multi_callback, &data, 1));
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch_empty);
+}
+
+void test_secp256k1_pippenger_bucket_window_inv(void) {
+    int i;
+
+    CHECK(secp256k1_pippenger_bucket_window_inv(0) == 0);
+    for(i = 1; i <= PIPPENGER_MAX_BUCKET_WINDOW; i++) {
+#ifdef USE_ENDOMORPHISM
+        /* Bucket_window of 8 is not used with endo */
+        if (i == 8) {
+            continue;
+        }
+#endif
+        CHECK(secp256k1_pippenger_bucket_window(secp256k1_pippenger_bucket_window_inv(i)) == i);
+        if (i != PIPPENGER_MAX_BUCKET_WINDOW) {
+            CHECK(secp256k1_pippenger_bucket_window(secp256k1_pippenger_bucket_window_inv(i)+1) > i);
+        }
+    }
+}
+
+/**
+ * Probabilistically test the function returning the maximum number of possible points
+ * for a given scratch space.
+ */
+void test_ecmult_multi_pippenger_max_points(void) {
+    size_t scratch_size = secp256k1_rand_int(256);
+    size_t max_size = secp256k1_pippenger_scratch_size(secp256k1_pippenger_bucket_window_inv(PIPPENGER_MAX_BUCKET_WINDOW-1)+512, 12);
+    secp256k1_scratch *scratch;
+    size_t n_points_supported;
+    int bucket_window = 0;
+
+    for(; scratch_size < max_size; scratch_size+=256) {
+        size_t i;
+        size_t total_alloc;
+        size_t checkpoint;
+        scratch = secp256k1_scratch_create(&ctx->error_callback, scratch_size);
+        CHECK(scratch != NULL);
+        checkpoint = secp256k1_scratch_checkpoint(&ctx->error_callback, scratch);
+        n_points_supported = secp256k1_pippenger_max_points(&ctx->error_callback, scratch);
+        if (n_points_supported == 0) {
+            secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+            continue;
+        }
+        bucket_window = secp256k1_pippenger_bucket_window(n_points_supported);
+        /* allocate `total_alloc` bytes over `PIPPENGER_SCRATCH_OBJECTS` many allocations */
+        total_alloc = secp256k1_pippenger_scratch_size(n_points_supported, bucket_window);
+        for (i = 0; i < PIPPENGER_SCRATCH_OBJECTS - 1; i++) {
+            CHECK(secp256k1_scratch_alloc(&ctx->error_callback, scratch, 1));
+            total_alloc--;
+        }
+        CHECK(secp256k1_scratch_alloc(&ctx->error_callback, scratch, total_alloc));
+        secp256k1_scratch_apply_checkpoint(&ctx->error_callback, scratch, checkpoint);
+        secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+    }
+    CHECK(bucket_window == PIPPENGER_MAX_BUCKET_WINDOW);
+}
+
+void test_ecmult_multi_batch_size_helper(void) {
+    size_t n_batches, n_batch_points, max_n_batch_points, n;
+
+    max_n_batch_points = 0;
+    n = 1;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 0);
+
+    max_n_batch_points = 1;
+    n = 0;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 1);
+    CHECK(n_batches == 0);
+    CHECK(n_batch_points == 0);
+
+    max_n_batch_points = 2;
+    n = 5;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 1);
+    CHECK(n_batches == 3);
+    CHECK(n_batch_points == 2);
+
+    max_n_batch_points = ECMULT_MAX_POINTS_PER_BATCH;
+    n = ECMULT_MAX_POINTS_PER_BATCH;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 1);
+    CHECK(n_batches == 1);
+    CHECK(n_batch_points == ECMULT_MAX_POINTS_PER_BATCH);
+
+    max_n_batch_points = ECMULT_MAX_POINTS_PER_BATCH + 1;
+    n = ECMULT_MAX_POINTS_PER_BATCH + 1;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 1);
+    CHECK(n_batches == 2);
+    CHECK(n_batch_points == ECMULT_MAX_POINTS_PER_BATCH/2 + 1);
+
+    max_n_batch_points = 1;
+    n = SIZE_MAX;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 1);
+    CHECK(n_batches == SIZE_MAX);
+    CHECK(n_batch_points == 1);
+
+    max_n_batch_points = 2;
+    n = SIZE_MAX;
+    CHECK(secp256k1_ecmult_multi_batch_size_helper(&n_batches, &n_batch_points, max_n_batch_points, n) == 1);
+    CHECK(n_batches == SIZE_MAX/2 + 1);
+    CHECK(n_batch_points == 2);
+}
+
+/**
+ * Run secp256k1_ecmult_multi_var with num points and a scratch space restricted to
+ * 1 <= i <= num points.
+ */
+void test_ecmult_multi_batching(void) {
+    static const int n_points = 2*ECMULT_PIPPENGER_THRESHOLD;
+    secp256k1_scalar scG;
+    secp256k1_scalar szero;
+    secp256k1_scalar *sc = (secp256k1_scalar *)checked_malloc(&ctx->error_callback, sizeof(secp256k1_scalar) * n_points);
+    secp256k1_ge *pt = (secp256k1_ge *)checked_malloc(&ctx->error_callback, sizeof(secp256k1_ge) * n_points);
+    secp256k1_gej r;
+    secp256k1_gej r2;
+    ecmult_multi_data data;
+    int i;
+    secp256k1_scratch *scratch;
+
+    secp256k1_gej_set_infinity(&r2);
+    secp256k1_scalar_set_int(&szero, 0);
+
+    /* Get random scalars and group elements and compute result */
+    random_scalar_order(&scG);
+    secp256k1_ecmult(&ctx->ecmult_ctx, &r2, &r2, &szero, &scG);
+    for(i = 0; i < n_points; i++) {
+        secp256k1_ge ptg;
+        secp256k1_gej ptgj;
+        random_group_element_test(&ptg);
+        secp256k1_gej_set_ge(&ptgj, &ptg);
+        pt[i] = ptg;
+        random_scalar_order(&sc[i]);
+        secp256k1_ecmult(&ctx->ecmult_ctx, &ptgj, &ptgj, &sc[i], NULL);
+        secp256k1_gej_add_var(&r2, &r2, &ptgj, NULL);
+    }
+    data.sc = sc;
+    data.pt = pt;
+    secp256k1_gej_neg(&r2, &r2);
+
+    /* Test with empty scratch space. It should compute the correct result using 
+     * ecmult_mult_simple algorithm which doesn't require a scratch space. */
+    scratch = secp256k1_scratch_create(&ctx->error_callback, 0);
+    CHECK(secp256k1_ecmult_multi_var(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &scG, ecmult_multi_callback, &data, n_points));
+    secp256k1_gej_add_var(&r, &r, &r2, NULL);
+    CHECK(secp256k1_gej_is_infinity(&r));
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+
+    /* Test with space for 1 point in pippenger. That's not enough because
+     * ecmult_multi selects strauss which requires more memory. It should
+     * therefore select the simple algorithm. */
+    scratch = secp256k1_scratch_create(&ctx->error_callback, secp256k1_pippenger_scratch_size(1, 1) + PIPPENGER_SCRATCH_OBJECTS*ALIGNMENT);
+    CHECK(secp256k1_ecmult_multi_var(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &scG, ecmult_multi_callback, &data, n_points));
+    secp256k1_gej_add_var(&r, &r, &r2, NULL);
+    CHECK(secp256k1_gej_is_infinity(&r));
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+
+    for(i = 1; i <= n_points; i++) {
+        if (i > ECMULT_PIPPENGER_THRESHOLD) {
+            int bucket_window = secp256k1_pippenger_bucket_window(i);
+            size_t scratch_size = secp256k1_pippenger_scratch_size(i, bucket_window);
+            scratch = secp256k1_scratch_create(&ctx->error_callback, scratch_size + PIPPENGER_SCRATCH_OBJECTS*ALIGNMENT);
+        } else {
+            size_t scratch_size = secp256k1_strauss_scratch_size(i);
+            scratch = secp256k1_scratch_create(&ctx->error_callback, scratch_size + STRAUSS_SCRATCH_OBJECTS*ALIGNMENT);
+        }
+        CHECK(secp256k1_ecmult_multi_var(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &r, &scG, ecmult_multi_callback, &data, n_points));
+        secp256k1_gej_add_var(&r, &r, &r2, NULL);
+        CHECK(secp256k1_gej_is_infinity(&r));
+        secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+    }
+    free(sc);
+    free(pt);
+}
+
+void run_ecmult_multi_tests(void) {
+    secp256k1_scratch *scratch;
+
+    test_secp256k1_pippenger_bucket_window_inv();
+    test_ecmult_multi_pippenger_max_points();
+    scratch = secp256k1_scratch_create(&ctx->error_callback, 819200);
+    test_ecmult_multi(scratch, secp256k1_ecmult_multi_var);
+    test_ecmult_multi(NULL, secp256k1_ecmult_multi_var);
+    test_ecmult_multi(scratch, secp256k1_ecmult_pippenger_batch_single);
+    test_ecmult_multi_batch_single(secp256k1_ecmult_pippenger_batch_single);
+    test_ecmult_multi(scratch, secp256k1_ecmult_strauss_batch_single);
+    test_ecmult_multi_batch_single(secp256k1_ecmult_strauss_batch_single);
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+
+    /* Run test_ecmult_multi with space for exactly one point */
+    scratch = secp256k1_scratch_create(&ctx->error_callback, secp256k1_strauss_scratch_size(1) + STRAUSS_SCRATCH_OBJECTS*ALIGNMENT);
+    test_ecmult_multi(scratch, secp256k1_ecmult_multi_var);
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+
+    test_ecmult_multi_batch_size_helper();
+    test_ecmult_multi_batching();
+}
+
 void test_wnaf(const secp256k1_scalar *number, int w) {
     secp256k1_scalar x, two, t;
     int wnaf[256];
@@ -2529,6 +3241,7 @@ void test_constant_wnaf(const secp256k1_scalar *number, int w) {
     int wnaf[256] = {0};
     int i;
     int skew;
+    int bits = 256;
     secp256k1_scalar num = *number;
 
     secp256k1_scalar_set_int(&x, 0);
@@ -2538,10 +3251,11 @@ void test_constant_wnaf(const secp256k1_scalar *number, int w) {
     for (i = 0; i < 16; ++i) {
         secp256k1_scalar_shr_int(&num, 8);
     }
+    bits = 128;
 #endif
-    skew = secp256k1_wnaf_const(wnaf, num, w);
+    skew = secp256k1_wnaf_const(wnaf, &num, w, bits);
 
-    for (i = WNAF_SIZE(w); i >= 0; --i) {
+    for (i = WNAF_SIZE_BITS(bits, w); i >= 0; --i) {
         secp256k1_scalar t;
         int v = wnaf[i];
         CHECK(v != 0); /* check nonzero */
@@ -2563,6 +3277,110 @@ void test_constant_wnaf(const secp256k1_scalar *number, int w) {
     CHECK(secp256k1_scalar_eq(&x, &num));
 }
 
+void test_fixed_wnaf(const secp256k1_scalar *number, int w) {
+    secp256k1_scalar x, shift;
+    int wnaf[256] = {0};
+    int i;
+    int skew;
+    secp256k1_scalar num = *number;
+
+    secp256k1_scalar_set_int(&x, 0);
+    secp256k1_scalar_set_int(&shift, 1 << w);
+    /* With USE_ENDOMORPHISM on we only consider 128-bit numbers */
+#ifdef USE_ENDOMORPHISM
+    for (i = 0; i < 16; ++i) {
+        secp256k1_scalar_shr_int(&num, 8);
+    }
+#endif
+    skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+
+    for (i = WNAF_SIZE(w)-1; i >= 0; --i) {
+        secp256k1_scalar t;
+        int v = wnaf[i];
+        CHECK(v == 0 || v & 1);  /* check parity */
+        CHECK(v > -(1 << w)); /* check range above */
+        CHECK(v < (1 << w));  /* check range below */
+
+        secp256k1_scalar_mul(&x, &x, &shift);
+        if (v >= 0) {
+            secp256k1_scalar_set_int(&t, v);
+        } else {
+            secp256k1_scalar_set_int(&t, -v);
+            secp256k1_scalar_negate(&t, &t);
+        }
+        secp256k1_scalar_add(&x, &x, &t);
+    }
+    /* If skew is 1 then add 1 to num */
+    secp256k1_scalar_cadd_bit(&num, 0, skew == 1);
+    CHECK(secp256k1_scalar_eq(&x, &num));
+}
+
+/* Checks that the first 8 elements of wnaf are equal to wnaf_expected and the
+ * rest is 0.*/
+void test_fixed_wnaf_small_helper(int *wnaf, int *wnaf_expected, int w) {
+    int i;
+    for (i = WNAF_SIZE(w)-1; i >= 8; --i) {
+        CHECK(wnaf[i] == 0);
+    }
+    for (i = 7; i >= 0; --i) {
+        CHECK(wnaf[i] == wnaf_expected[i]);
+    }
+}
+
+void test_fixed_wnaf_small(void) {
+    int w = 4;
+    int wnaf[256] = {0};
+    int i;
+    int skew;
+    secp256k1_scalar num;
+
+    secp256k1_scalar_set_int(&num, 0);
+    skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+    for (i = WNAF_SIZE(w)-1; i >= 0; --i) {
+        int v = wnaf[i];
+        CHECK(v == 0);
+    }
+    CHECK(skew == 0);
+
+    secp256k1_scalar_set_int(&num, 1);
+    skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+    for (i = WNAF_SIZE(w)-1; i >= 1; --i) {
+        int v = wnaf[i];
+        CHECK(v == 0);
+    }
+    CHECK(wnaf[0] == 1);
+    CHECK(skew == 0);
+
+    {
+        int wnaf_expected[8] = { 0xf, 0xf, 0xf, 0xf, 0xf, 0xf, 0xf, 0xf };
+        secp256k1_scalar_set_int(&num, 0xffffffff);
+        skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+        test_fixed_wnaf_small_helper(wnaf, wnaf_expected, w);
+        CHECK(skew == 0);
+    }
+    {
+        int wnaf_expected[8] = { -1, -1, -1, -1, -1, -1, -1, 0xf };
+        secp256k1_scalar_set_int(&num, 0xeeeeeeee);
+        skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+        test_fixed_wnaf_small_helper(wnaf, wnaf_expected, w);
+        CHECK(skew == 1);
+    }
+    {
+        int wnaf_expected[8] = { 1, 0, 1, 0, 1, 0, 1, 0 };
+        secp256k1_scalar_set_int(&num, 0x01010101);
+        skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+        test_fixed_wnaf_small_helper(wnaf, wnaf_expected, w);
+        CHECK(skew == 0);
+    }
+    {
+        int wnaf_expected[8] = { -0xf, 0, 0xf, -0xf, 0, 0xf, 1, 0 };
+        secp256k1_scalar_set_int(&num, 0x01ef1ef1);
+        skew = secp256k1_wnaf_fixed(wnaf, &num, w);
+        test_fixed_wnaf_small_helper(wnaf, wnaf_expected, w);
+        CHECK(skew == 0);
+    }
+}
+
 void run_wnaf(void) {
     int i;
     secp256k1_scalar n = {{0}};
@@ -2573,12 +3391,15 @@ void run_wnaf(void) {
     test_constant_wnaf(&n, 4);
     n.d[0] = 2;
     test_constant_wnaf(&n, 4);
+    /* Test 0 */
+    test_fixed_wnaf_small();
     /* Random tests */
     for (i = 0; i < count; i++) {
         random_scalar_order(&n);
         test_wnaf(&n, 4+(i%10));
         test_constant_wnaf_negate(&n);
         test_constant_wnaf(&n, 4 + (i % 10));
+        test_fixed_wnaf(&n, 4 + (i % 10));
     }
     secp256k1_scalar_set_int(&n, 0);
     CHECK(secp256k1_scalar_cond_negate(&n, 1) == -1);
@@ -3043,6 +3864,7 @@ void run_ec_pubkey_parse_test(void) {
     ecount = 0;
     VG_UNDEF(&pubkey, sizeof(pubkey));
     CHECK(secp256k1_ec_pubkey_parse(ctx, &pubkey, pubkeyc, 65) == 1);
+    CHECK(secp256k1_ec_pubkey_parse(secp256k1_context_no_precomp, &pubkey, pubkeyc, 65) == 1);
     VG_CHECK(&pubkey, sizeof(pubkey));
     CHECK(ecount == 0);
     VG_UNDEF(&ge, sizeof(ge));
@@ -3165,39 +3987,59 @@ void run_eckey_edge_case_test(void) {
     VG_CHECK(&pubkey, sizeof(pubkey));
     CHECK(memcmp(&pubkey, zeros, sizeof(secp256k1_pubkey)) > 0);
     pubkey_negone = pubkey;
-    /* Tweak of zero leaves the value changed. */
+    /* Tweak of zero leaves the value unchanged. */
     memset(ctmp2, 0, 32);
-    CHECK(secp256k1_ec_privkey_tweak_add(ctx, ctmp, ctmp2) == 1);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, ctmp, ctmp2) == 1);
     CHECK(memcmp(orderc, ctmp, 31) == 0 && ctmp[31] == 0x40);
     memcpy(&pubkey2, &pubkey, sizeof(pubkey));
     CHECK(secp256k1_ec_pubkey_tweak_add(ctx, &pubkey, ctmp2) == 1);
     CHECK(memcmp(&pubkey, &pubkey2, sizeof(pubkey)) == 0);
     /* Multiply tweak of zero zeroizes the output. */
-    CHECK(secp256k1_ec_privkey_tweak_mul(ctx, ctmp, ctmp2) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_mul(ctx, ctmp, ctmp2) == 0);
     CHECK(memcmp(zeros, ctmp, 32) == 0);
     CHECK(secp256k1_ec_pubkey_tweak_mul(ctx, &pubkey, ctmp2) == 0);
     CHECK(memcmp(&pubkey, zeros, sizeof(pubkey)) == 0);
     memcpy(&pubkey, &pubkey2, sizeof(pubkey));
-    /* Overflowing key tweak zeroizes. */
+    /* If seckey_tweak_add or seckey_tweak_mul are called with an overflowing
+    seckey, the seckey is zeroized. */
+    memcpy(ctmp, orderc, 32);
+    memset(ctmp2, 0, 32);
+    ctmp2[31] = 0x01;
+    CHECK(secp256k1_ec_seckey_verify(ctx, ctmp2) == 1);
+    CHECK(secp256k1_ec_seckey_verify(ctx, ctmp) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, ctmp, ctmp2) == 0);
+    CHECK(memcmp(zeros, ctmp, 32) == 0);
+    memcpy(ctmp, orderc, 32);
+    CHECK(secp256k1_ec_seckey_tweak_mul(ctx, ctmp, ctmp2) == 0);
+    CHECK(memcmp(zeros, ctmp, 32) == 0);
+    /* If seckey_tweak_add or seckey_tweak_mul are called with an overflowing
+    tweak, the seckey is zeroized. */
     memcpy(ctmp, orderc, 32);
     ctmp[31] = 0x40;
-    CHECK(secp256k1_ec_privkey_tweak_add(ctx, ctmp, orderc) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, ctmp, orderc) == 0);
     CHECK(memcmp(zeros, ctmp, 32) == 0);
     memcpy(ctmp, orderc, 32);
     ctmp[31] = 0x40;
-    CHECK(secp256k1_ec_privkey_tweak_mul(ctx, ctmp, orderc) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_mul(ctx, ctmp, orderc) == 0);
     CHECK(memcmp(zeros, ctmp, 32) == 0);
     memcpy(ctmp, orderc, 32);
     ctmp[31] = 0x40;
+    /* If pubkey_tweak_add or pubkey_tweak_mul are called with an overflowing
+    tweak, the pubkey is zeroized. */
     CHECK(secp256k1_ec_pubkey_tweak_add(ctx, &pubkey, orderc) == 0);
     CHECK(memcmp(&pubkey, zeros, sizeof(pubkey)) == 0);
     memcpy(&pubkey, &pubkey2, sizeof(pubkey));
     CHECK(secp256k1_ec_pubkey_tweak_mul(ctx, &pubkey, orderc) == 0);
     CHECK(memcmp(&pubkey, zeros, sizeof(pubkey)) == 0);
     memcpy(&pubkey, &pubkey2, sizeof(pubkey));
-    /* Private key tweaks results in a key of zero. */
+    /* If the resulting key in secp256k1_ec_seckey_tweak_add and
+     * secp256k1_ec_pubkey_tweak_add is 0 the functions fail and in the latter
+     * case the pubkey is zeroized. */
+    memcpy(ctmp, orderc, 32);
+    ctmp[31] = 0x40;
+    memset(ctmp2, 0, 32);
     ctmp2[31] = 1;
-    CHECK(secp256k1_ec_privkey_tweak_add(ctx, ctmp2, ctmp) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, ctmp2, ctmp) == 0);
     CHECK(memcmp(zeros, ctmp2, 32) == 0);
     ctmp2[31] = 1;
     CHECK(secp256k1_ec_pubkey_tweak_add(ctx, &pubkey, ctmp2) == 0);
@@ -3205,7 +4047,7 @@ void run_eckey_edge_case_test(void) {
     memcpy(&pubkey, &pubkey2, sizeof(pubkey));
     /* Tweak computation wraps and results in a key of 1. */
     ctmp2[31] = 2;
-    CHECK(secp256k1_ec_privkey_tweak_add(ctx, ctmp2, ctmp) == 1);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, ctmp2, ctmp) == 1);
     CHECK(memcmp(ctmp2, zeros, 31) == 0 && ctmp2[31] == 1);
     ctmp2[31] = 2;
     CHECK(secp256k1_ec_pubkey_tweak_add(ctx, &pubkey, ctmp2) == 1);
@@ -3253,16 +4095,16 @@ void run_eckey_edge_case_test(void) {
     CHECK(ecount == 2);
     ecount = 0;
     memset(ctmp2, 0, 32);
-    CHECK(secp256k1_ec_privkey_tweak_add(ctx, NULL, ctmp2) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, NULL, ctmp2) == 0);
     CHECK(ecount == 1);
-    CHECK(secp256k1_ec_privkey_tweak_add(ctx, ctmp, NULL) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_add(ctx, ctmp, NULL) == 0);
     CHECK(ecount == 2);
     ecount = 0;
     memset(ctmp2, 0, 32);
     ctmp2[31] = 1;
-    CHECK(secp256k1_ec_privkey_tweak_mul(ctx, NULL, ctmp2) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_mul(ctx, NULL, ctmp2) == 0);
     CHECK(ecount == 1);
-    CHECK(secp256k1_ec_privkey_tweak_mul(ctx, ctmp, NULL) == 0);
+    CHECK(secp256k1_ec_seckey_tweak_mul(ctx, ctmp, NULL) == 0);
     CHECK(ecount == 2);
     ecount = 0;
     CHECK(secp256k1_ec_pubkey_create(ctx, NULL, ctmp) == 0);
@@ -3335,6 +4177,41 @@ void run_eckey_edge_case_test(void) {
     secp256k1_context_set_illegal_callback(ctx, NULL, NULL);
 }
 
+void run_eckey_negate_test(void) {
+    unsigned char seckey[32];
+    unsigned char seckey_tmp[32];
+
+    random_scalar_order_b32(seckey);
+    memcpy(seckey_tmp, seckey, 32);
+
+    /* Verify negation changes the key and changes it back */
+    CHECK(secp256k1_ec_seckey_negate(ctx, seckey) == 1);
+    CHECK(memcmp(seckey, seckey_tmp, 32) != 0);
+    CHECK(secp256k1_ec_seckey_negate(ctx, seckey) == 1);
+    CHECK(memcmp(seckey, seckey_tmp, 32) == 0);
+
+    /* Check that privkey alias gives same result */
+    CHECK(secp256k1_ec_seckey_negate(ctx, seckey) == 1);
+    CHECK(secp256k1_ec_privkey_negate(ctx, seckey_tmp) == 1);
+    CHECK(memcmp(seckey, seckey_tmp, 32) == 0);
+
+    /* Negating all 0s fails */
+    memset(seckey, 0, 32);
+    memset(seckey_tmp, 0, 32);
+    CHECK(secp256k1_ec_seckey_negate(ctx, seckey) == 0);
+    /* Check that seckey is not modified */
+    CHECK(memcmp(seckey, seckey_tmp, 32) == 0);
+
+    /* Negating an overflowing seckey fails and the seckey is zeroed. In this
+     * test, the seckey has 16 random bytes to ensure that ec_seckey_negate
+     * doesn't just set seckey to a constant value in case of failure. */
+    random_scalar_order_b32(seckey);
+    memset(seckey, 0xFF, 16);
+    memset(seckey_tmp, 0, 32);
+    CHECK(secp256k1_ec_seckey_negate(ctx, seckey) == 0);
+    CHECK(memcmp(seckey, seckey_tmp, 32) == 0);
+}
+
 void random_sign(secp256k1_scalar *sigr, secp256k1_scalar *sigs, const secp256k1_scalar *key, const secp256k1_scalar *msg, int *recid) {
     secp256k1_scalar nonce;
     do {
@@ -3436,6 +4313,7 @@ void test_ecdsa_end_to_end(void) {
     unsigned char pubkeyc[65];
     size_t pubkeyclen = 65;
     secp256k1_pubkey pubkey;
+    secp256k1_pubkey pubkey_tmp;
     unsigned char seckey[300];
     size_t seckeylen = 300;
 
@@ -3457,6 +4335,13 @@ void test_ecdsa_end_to_end(void) {
     memset(&pubkey, 0, sizeof(pubkey));
     CHECK(secp256k1_ec_pubkey_parse(ctx, &pubkey, pubkeyc, pubkeyclen) == 1);
 
+    /* Verify negation changes the key and changes it back */
+    memcpy(&pubkey_tmp, &pubkey, sizeof(pubkey));
+    CHECK(secp256k1_ec_pubkey_negate(ctx, &pubkey_tmp) == 1);
+    CHECK(memcmp(&pubkey_tmp, &pubkey, sizeof(pubkey)) != 0);
+    CHECK(secp256k1_ec_pubkey_negate(ctx, &pubkey_tmp) == 1);
+    CHECK(memcmp(&pubkey_tmp, &pubkey, sizeof(pubkey)) == 0);
+
     /* Verify private key import and export. */
     CHECK(ec_privkey_export_der(ctx, seckey, &seckeylen, privkey, secp256k1_rand_bits(1) == 1));
     CHECK(ec_privkey_import_der(ctx, privkey2, seckey, seckeylen) == 1);
@@ -3466,15 +4351,22 @@ void test_ecdsa_end_to_end(void) {
     if (secp256k1_rand_int(3) == 0) {
         int ret1;
         int ret2;
+        int ret3;
         unsigned char rnd[32];
+        unsigned char privkey_tmp[32];
         secp256k1_pubkey pubkey2;
         secp256k1_rand256_test(rnd);
-        ret1 = secp256k1_ec_privkey_tweak_add(ctx, privkey, rnd);
+        memcpy(privkey_tmp, privkey, 32);
+        ret1 = secp256k1_ec_seckey_tweak_add(ctx, privkey, rnd);
         ret2 = secp256k1_ec_pubkey_tweak_add(ctx, &pubkey, rnd);
+        /* Check that privkey alias gives same result */
+        ret3 = secp256k1_ec_privkey_tweak_add(ctx, privkey_tmp, rnd);
         CHECK(ret1 == ret2);
+        CHECK(ret2 == ret3);
         if (ret1 == 0) {
             return;
         }
+        CHECK(memcmp(privkey, privkey_tmp, 32) == 0);
         CHECK(secp256k1_ec_pubkey_create(ctx, &pubkey2, privkey) == 1);
         CHECK(memcmp(&pubkey, &pubkey2, sizeof(pubkey)) == 0);
     }
@@ -3483,15 +4375,22 @@ void test_ecdsa_end_to_end(void) {
     if (secp256k1_rand_int(3) == 0) {
         int ret1;
         int ret2;
+        int ret3;
         unsigned char rnd[32];
+        unsigned char privkey_tmp[32];
         secp256k1_pubkey pubkey2;
         secp256k1_rand256_test(rnd);
-        ret1 = secp256k1_ec_privkey_tweak_mul(ctx, privkey, rnd);
+        memcpy(privkey_tmp, privkey, 32);
+        ret1 = secp256k1_ec_seckey_tweak_mul(ctx, privkey, rnd);
         ret2 = secp256k1_ec_pubkey_tweak_mul(ctx, &pubkey, rnd);
+        /* Check that privkey alias gives same result */
+        ret3 = secp256k1_ec_privkey_tweak_mul(ctx, privkey_tmp, rnd);
         CHECK(ret1 == ret2);
+        CHECK(ret2 == ret3);
         if (ret1 == 0) {
             return;
         }
+        CHECK(memcmp(privkey, privkey_tmp, 32) == 0);
         CHECK(secp256k1_ec_pubkey_create(ctx, &pubkey2, privkey) == 1);
         CHECK(memcmp(&pubkey, &pubkey2, sizeof(pubkey)) == 0);
     }
@@ -3648,6 +4547,7 @@ int test_ecdsa_der_parse(const unsigned char *sig, size_t siglen, int certainly_
 
 #ifdef ENABLE_OPENSSL_TESTS
     ECDSA_SIG *sig_openssl;
+    const BIGNUM *r = NULL, *s = NULL;
     const unsigned char *sigptr;
     unsigned char roundtrip_openssl[2048];
     int len_openssl = 2048;
@@ -3687,7 +4587,7 @@ int test_ecdsa_der_parse(const unsigned char *sig, size_t siglen, int certainly_
     if (valid_der) {
         ret |= (!roundtrips_der_lax) << 12;
         ret |= (len_der != len_der_lax) << 13;
-        ret |= (memcmp(roundtrip_der_lax, roundtrip_der, len_der) != 0) << 14;
+        ret |= ((len_der != len_der_lax) || (memcmp(roundtrip_der_lax, roundtrip_der, len_der) != 0)) << 14;
     }
     ret |= (roundtrips_der != roundtrips_der_lax) << 15;
     if (parsed_der) {
@@ -3699,15 +4599,16 @@ int test_ecdsa_der_parse(const unsigned char *sig, size_t siglen, int certainly_
     sigptr = sig;
     parsed_openssl = (d2i_ECDSA_SIG(&sig_openssl, &sigptr, siglen) != NULL);
     if (parsed_openssl) {
-        valid_openssl = !BN_is_negative(sig_openssl->r) && !BN_is_negative(sig_openssl->s) && BN_num_bits(sig_openssl->r) > 0 && BN_num_bits(sig_openssl->r) <= 256 && BN_num_bits(sig_openssl->s) > 0 && BN_num_bits(sig_openssl->s) <= 256;
+        ECDSA_SIG_get0(sig_openssl, &r, &s);
+        valid_openssl = !BN_is_negative(r) && !BN_is_negative(s) && BN_num_bits(r) > 0 && BN_num_bits(r) <= 256 && BN_num_bits(s) > 0 && BN_num_bits(s) <= 256;
         if (valid_openssl) {
             unsigned char tmp[32] = {0};
-            BN_bn2bin(sig_openssl->r, tmp + 32 - BN_num_bytes(sig_openssl->r));
+            BN_bn2bin(r, tmp + 32 - BN_num_bytes(r));
             valid_openssl = memcmp(tmp, max_scalar, 32) < 0;
         }
         if (valid_openssl) {
             unsigned char tmp[32] = {0};
-            BN_bn2bin(sig_openssl->s, tmp + 32 - BN_num_bytes(sig_openssl->s));
+            BN_bn2bin(s, tmp + 32 - BN_num_bytes(s));
             valid_openssl = memcmp(tmp, max_scalar, 32) < 0;
         }
     }
@@ -3727,7 +4628,7 @@ int test_ecdsa_der_parse(const unsigned char *sig, size_t siglen, int certainly_
     ret |= (roundtrips_der != roundtrips_openssl) << 7;
     if (roundtrips_openssl) {
         ret |= (len_der != (size_t)len_openssl) << 8;
-        ret |= (memcmp(roundtrip_der, roundtrip_openssl, len_der) != 0) << 9;
+        ret |= ((len_der != (size_t)len_openssl) || (memcmp(roundtrip_der, roundtrip_openssl, len_der) != 0)) << 9;
     }
 #endif
     return ret;
@@ -4383,17 +5284,37 @@ void run_ecdsa_openssl(void) {
 # include "modules/ecdh/tests_impl.h"
 #endif
 
-#ifdef ENABLE_MODULE_SCHNORR
-# include "modules/schnorr/tests_impl.h"
-#endif
-
 #ifdef ENABLE_MODULE_RECOVERY
 # include "modules/recovery/tests_impl.h"
 #endif
 
+void run_memczero_test(void) {
+    unsigned char buf1[6] = {1, 2, 3, 4, 5, 6};
+    unsigned char buf2[sizeof(buf1)];
+
+    /* memczero(..., ..., 0) is a noop. */
+    memcpy(buf2, buf1, sizeof(buf1));
+    memczero(buf1, sizeof(buf1), 0);
+    CHECK(memcmp(buf1, buf2, sizeof(buf1)) == 0);
+
+    /* memczero(..., ..., 1) zeros the buffer. */
+    memset(buf2, 0, sizeof(buf2));
+    memczero(buf1, sizeof(buf1) , 1);
+    CHECK(memcmp(buf1, buf2, sizeof(buf1)) == 0);
+}
+
 int main(int argc, char **argv) {
     unsigned char seed16[16] = {0};
     unsigned char run32[32] = {0};
+
+    /* Disable buffering for stdout to improve reliability of getting
+     * diagnostic information. Happens right at the start of main because
+     * setbuf must be used before any other operation on the stream. */
+    setbuf(stdout, NULL);
+    /* Also disable buffering for stderr because it's not guaranteed that it's
+     * unbuffered on all systems. */
+    setbuf(stderr, NULL);
+
     /* find iteration count */
     if (argc > 1) {
         count = strtol(argv[1], NULL, 0);
@@ -4405,7 +5326,7 @@ int main(int argc, char **argv) {
         const char* ch = argv[2];
         while (pos < 16 && ch[0] != 0 && ch[1] != 0) {
             unsigned short sh;
-            if (sscanf(ch, "%2hx", &sh)) {
+            if ((sscanf(ch, "%2hx", &sh)) == 1) {
                 seed16[pos] = sh;
             } else {
                 break;
@@ -4415,8 +5336,9 @@ int main(int argc, char **argv) {
         }
     } else {
         FILE *frand = fopen("/dev/urandom", "r");
-        if ((frand == NULL) || !fread(&seed16, sizeof(seed16), 1, frand)) {
+        if ((frand == NULL) || fread(&seed16, 1, sizeof(seed16), frand) != sizeof(seed16)) {
             uint64_t t = time(NULL) * (uint64_t)1337;
+            fprintf(stderr, "WARNING: could not read 16 bytes from /dev/urandom; falling back to insecure PRNG\n");
             seed16[0] ^= t;
             seed16[1] ^= t >> 8;
             seed16[2] ^= t >> 16;
@@ -4426,7 +5348,9 @@ int main(int argc, char **argv) {
             seed16[6] ^= t >> 48;
             seed16[7] ^= t >> 56;
         }
-        fclose(frand);
+        if (frand) {
+            fclose(frand);
+        }
     }
     secp256k1_rand_seed(seed16);
 
@@ -4434,7 +5358,9 @@ int main(int argc, char **argv) {
     printf("random seed = %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x\n", seed16[0], seed16[1], seed16[2], seed16[3], seed16[4], seed16[5], seed16[6], seed16[7], seed16[8], seed16[9], seed16[10], seed16[11], seed16[12], seed16[13], seed16[14], seed16[15]);
 
     /* initialize */
-    run_context_tests();
+    run_context_tests(0);
+    run_context_tests(1);
+    run_scratch_tests();
     ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
     if (secp256k1_rand_bits(1)) {
         secp256k1_rand256(run32);
@@ -4476,6 +5402,7 @@ int main(int argc, char **argv) {
     run_ecmult_constants();
     run_ecmult_gen_blind();
     run_ecmult_const_tests();
+    run_ecmult_multi_tests();
     run_ec_combine();
 
     /* endomorphism tests */
@@ -4489,6 +5416,9 @@ int main(int argc, char **argv) {
     /* EC key edge cases */
     run_eckey_edge_case_test();
 
+    /* EC key arithmetic test */
+    run_eckey_negate_test();
+
 #ifdef ENABLE_MODULE_ECDH
     /* ecdh tests */
     run_ecdh_tests();
@@ -4504,16 +5434,14 @@ int main(int argc, char **argv) {
     run_ecdsa_openssl();
 #endif
 
-#ifdef ENABLE_MODULE_SCHNORR
-    /* Schnorr tests */
-    run_schnorr_tests();
-#endif
-
 #ifdef ENABLE_MODULE_RECOVERY
     /* ECDSA pubkey recovery tests */
     run_recovery_tests();
 #endif
 
+    /* util tests */
+    run_memczero_test();
+
     secp256k1_rand256(run32);
     printf("random run = %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x\n", run32[0], run32[1], run32[2], run32[3], run32[4], run32[5], run32[6], run32[7], run32[8], run32[9], run32[10], run32[11], run32[12], run32[13], run32[14], run32[15]);
 
diff --git a/crypto/secp256k1/libsecp256k1/src/tests_exhaustive.c b/crypto/secp256k1/libsecp256k1/src/tests_exhaustive.c
index b040bb073..8cca1cef2 100644
--- a/crypto/secp256k1/libsecp256k1/src/tests_exhaustive.c
+++ b/crypto/secp256k1/libsecp256k1/src/tests_exhaustive.c
@@ -142,7 +142,7 @@ void test_exhaustive_addition(const secp256k1_ge *group, const secp256k1_gej *gr
     for (i = 0; i < order; i++) {
         secp256k1_gej tmp;
         if (i > 0) {
-            secp256k1_gej_double_nonzero(&tmp, &groupj[i], NULL);
+            secp256k1_gej_double_nonzero(&tmp, &groupj[i]);
             ge_equals_gej(&group[(2 * i) % order], &tmp);
         }
         secp256k1_gej_double_var(&tmp, &groupj[i], NULL);
@@ -174,7 +174,7 @@ void test_exhaustive_ecmult(const secp256k1_context *ctx, const secp256k1_ge *gr
                 ge_equals_gej(&group[(i * r_log + j) % order], &tmp);
 
                 if (i > 0) {
-                    secp256k1_ecmult_const(&tmp, &group[i], &ng);
+                    secp256k1_ecmult_const(&tmp, &group[i], &ng, 256);
                     ge_equals_gej(&group[(i * j) % order], &tmp);
                 }
             }
@@ -182,6 +182,46 @@ void test_exhaustive_ecmult(const secp256k1_context *ctx, const secp256k1_ge *gr
     }
 }
 
+typedef struct {
+    secp256k1_scalar sc[2];
+    secp256k1_ge pt[2];
+} ecmult_multi_data;
+
+static int ecmult_multi_callback(secp256k1_scalar *sc, secp256k1_ge *pt, size_t idx, void *cbdata) {
+    ecmult_multi_data *data = (ecmult_multi_data*) cbdata;
+    *sc = data->sc[idx];
+    *pt = data->pt[idx];
+    return 1;
+}
+
+void test_exhaustive_ecmult_multi(const secp256k1_context *ctx, const secp256k1_ge *group, int order) {
+    int i, j, k, x, y;
+    secp256k1_scratch *scratch = secp256k1_scratch_create(&ctx->error_callback, 4096);
+    for (i = 0; i < order; i++) {
+        for (j = 0; j < order; j++) {
+            for (k = 0; k < order; k++) {
+                for (x = 0; x < order; x++) {
+                    for (y = 0; y < order; y++) {
+                        secp256k1_gej tmp;
+                        secp256k1_scalar g_sc;
+                        ecmult_multi_data data;
+
+                        secp256k1_scalar_set_int(&data.sc[0], i);
+                        secp256k1_scalar_set_int(&data.sc[1], j);
+                        secp256k1_scalar_set_int(&g_sc, k);
+                        data.pt[0] = group[x];
+                        data.pt[1] = group[y];
+
+                        secp256k1_ecmult_multi_var(&ctx->error_callback, &ctx->ecmult_ctx, scratch, &tmp, &g_sc, ecmult_multi_callback, &data, 2);
+                        ge_equals_gej(&group[(i * x + j * y + k) % order], &tmp);
+                    }
+                }
+            }
+        }
+    }
+    secp256k1_scratch_destroy(&ctx->error_callback, scratch);
+}
+
 void r_from_k(secp256k1_scalar *r, const secp256k1_ge *group, int k) {
     secp256k1_fe x;
     unsigned char x_bin[32];
@@ -456,6 +496,7 @@ int main(void) {
 #endif
     test_exhaustive_addition(group, groupj, EXHAUSTIVE_TEST_ORDER);
     test_exhaustive_ecmult(ctx, group, groupj, EXHAUSTIVE_TEST_ORDER);
+    test_exhaustive_ecmult_multi(ctx, group, EXHAUSTIVE_TEST_ORDER);
     test_exhaustive_sign(ctx, group, EXHAUSTIVE_TEST_ORDER);
     test_exhaustive_verify(ctx, group, EXHAUSTIVE_TEST_ORDER);
 
diff --git a/crypto/secp256k1/libsecp256k1/src/util.h b/crypto/secp256k1/libsecp256k1/src/util.h
index 4092a86c9..9a86e7875 100644
--- a/crypto/secp256k1/libsecp256k1/src/util.h
+++ b/crypto/secp256k1/libsecp256k1/src/util.h
@@ -4,8 +4,8 @@
  * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
  **********************************************************************/
 
-#ifndef _SECP256K1_UTIL_H_
-#define _SECP256K1_UTIL_H_
+#ifndef SECP256K1_UTIL_H
+#define SECP256K1_UTIL_H
 
 #if defined HAVE_CONFIG_H
 #include "libsecp256k1-config.h"
@@ -14,6 +14,7 @@
 #include <stdlib.h>
 #include <stdint.h>
 #include <stdio.h>
+#include <limits.h>
 
 typedef struct {
     void (*fn)(const char *text, void* data);
@@ -36,7 +37,7 @@ static SECP256K1_INLINE void secp256k1_callback_call(const secp256k1_callback *
 } while(0)
 #endif
 
-#ifdef HAVE_BUILTIN_EXPECT
+#if SECP256K1_GNUC_PREREQ(3, 0)
 #define EXPECT(x,c) __builtin_expect((x),(c))
 #else
 #define EXPECT(x,c) (x)
@@ -76,6 +77,55 @@ static SECP256K1_INLINE void *checked_malloc(const secp256k1_callback* cb, size_
     return ret;
 }
 
+static SECP256K1_INLINE void *checked_realloc(const secp256k1_callback* cb, void *ptr, size_t size) {
+    void *ret = realloc(ptr, size);
+    if (ret == NULL) {
+        secp256k1_callback_call(cb, "Out of memory");
+    }
+    return ret;
+}
+
+#if defined(__BIGGEST_ALIGNMENT__)
+#define ALIGNMENT __BIGGEST_ALIGNMENT__
+#else
+/* Using 16 bytes alignment because common architectures never have alignment
+ * requirements above 8 for any of the types we care about. In addition we
+ * leave some room because currently we don't care about a few bytes. */
+#define ALIGNMENT 16
+#endif
+
+#define ROUND_TO_ALIGN(size) (((size + ALIGNMENT - 1) / ALIGNMENT) * ALIGNMENT)
+
+/* Assume there is a contiguous memory object with bounds [base, base + max_size)
+ * of which the memory range [base, *prealloc_ptr) is already allocated for usage,
+ * where *prealloc_ptr is an aligned pointer. In that setting, this functions
+ * reserves the subobject [*prealloc_ptr, *prealloc_ptr + alloc_size) of
+ * alloc_size bytes by increasing *prealloc_ptr accordingly, taking into account
+ * alignment requirements.
+ *
+ * The function returns an aligned pointer to the newly allocated subobject.
+ *
+ * This is useful for manual memory management: if we're simply given a block
+ * [base, base + max_size), the caller can use this function to allocate memory
+ * in this block and keep track of the current allocation state with *prealloc_ptr.
+ *
+ * It is VERIFY_CHECKed that there is enough space left in the memory object and
+ * *prealloc_ptr is aligned relative to base.
+ */
+static SECP256K1_INLINE void *manual_alloc(void** prealloc_ptr, size_t alloc_size, void* base, size_t max_size) {
+    size_t aligned_alloc_size = ROUND_TO_ALIGN(alloc_size);
+    void* ret;
+    VERIFY_CHECK(prealloc_ptr != NULL);
+    VERIFY_CHECK(*prealloc_ptr != NULL);
+    VERIFY_CHECK(base != NULL);
+    VERIFY_CHECK((unsigned char*)*prealloc_ptr >= (unsigned char*)base);
+    VERIFY_CHECK(((unsigned char*)*prealloc_ptr - (unsigned char*)base) % ALIGNMENT == 0);
+    VERIFY_CHECK((unsigned char*)*prealloc_ptr - (unsigned char*)base + aligned_alloc_size <= max_size);
+    ret = *prealloc_ptr;
+    *((unsigned char**)prealloc_ptr) += aligned_alloc_size;
+    return ret;
+}
+
 /* Macro for restrict, when available and not in a VERIFY build. */
 #if defined(SECP256K1_BUILD) && defined(VERIFY)
 # define SECP256K1_RESTRICT
@@ -110,4 +160,19 @@ static SECP256K1_INLINE void *checked_malloc(const secp256k1_callback* cb, size_
 SECP256K1_GNUC_EXT typedef unsigned __int128 uint128_t;
 #endif
 
-#endif
+/* Zero memory if flag == 1. Flag must be 0 or 1. Constant time. */
+static SECP256K1_INLINE void memczero(void *s, size_t len, int flag) {
+    unsigned char *p = (unsigned char *)s;
+    /* Access flag with a volatile-qualified lvalue.
+       This prevents clang from figuring out (after inlining) that flag can
+       take only be 0 or 1, which leads to variable time code. */
+    volatile int vflag = flag;
+    unsigned char mask = -(unsigned char) vflag;
+    while (len) {
+        *p &= ~mask;
+        p++;
+        len--;
+    }
+}
+
+#endif /* SECP256K1_UTIL_H */
diff --git a/crypto/secp256k1/libsecp256k1/src/valgrind_ctime_test.c b/crypto/secp256k1/libsecp256k1/src/valgrind_ctime_test.c
new file mode 100644
index 000000000..5d26244db
--- /dev/null
+++ b/crypto/secp256k1/libsecp256k1/src/valgrind_ctime_test.c
@@ -0,0 +1,100 @@
+/**********************************************************************
+ * Copyright (c) 2020 Gregory Maxwell                                 *
+ * Distributed under the MIT software license, see the accompanying   *
+ * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
+ **********************************************************************/
+
+#include <valgrind/memcheck.h>
+#include "include/secp256k1.h"
+#include "util.h"
+
+#if ENABLE_MODULE_ECDH
+# include "include/secp256k1_ecdh.h"
+#endif
+
+int main(void) {
+    secp256k1_context* ctx;
+    secp256k1_ecdsa_signature signature;
+    secp256k1_pubkey pubkey;
+    size_t siglen = 74;
+    size_t outputlen = 33;
+    int i;
+    int ret;
+    unsigned char msg[32];
+    unsigned char key[32];
+    unsigned char sig[74];
+    unsigned char spubkey[33];
+
+    if (!RUNNING_ON_VALGRIND) {
+        fprintf(stderr, "This test can only usefully be run inside valgrind.\n");
+        fprintf(stderr, "Usage: libtool --mode=execute valgrind ./valgrind_ctime_test\n");
+        exit(1);
+    }
+
+    /** In theory, testing with a single secret input should be sufficient:
+     *  If control flow depended on secrets the tool would generate an error.
+     */
+    for (i = 0; i < 32; i++) {
+        key[i] = i + 65;
+    }
+    for (i = 0; i < 32; i++) {
+        msg[i] = i + 1;
+    }
+
+    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_DECLASSIFY);
+
+    /* Test keygen. */
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    ret = secp256k1_ec_pubkey_create(ctx, &pubkey, key);
+    VALGRIND_MAKE_MEM_DEFINED(&pubkey, sizeof(secp256k1_pubkey));
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret);
+    CHECK(secp256k1_ec_pubkey_serialize(ctx, spubkey, &outputlen, &pubkey, SECP256K1_EC_COMPRESSED) == 1);
+
+    /* Test signing. */
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    ret = secp256k1_ecdsa_sign(ctx, &signature, msg, key, NULL, NULL);
+    VALGRIND_MAKE_MEM_DEFINED(&signature, sizeof(secp256k1_ecdsa_signature));
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret);
+    CHECK(secp256k1_ecdsa_signature_serialize_der(ctx, sig, &siglen, &signature));
+
+#if ENABLE_MODULE_ECDH
+    /* Test ECDH. */
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    ret = secp256k1_ecdh(ctx, msg, &pubkey, key, NULL, NULL);
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret == 1);
+#endif
+
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    ret = secp256k1_ec_seckey_verify(ctx, key);
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret == 1);
+
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    ret = secp256k1_ec_seckey_negate(ctx, key);
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret == 1);
+
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    VALGRIND_MAKE_MEM_UNDEFINED(msg, 32);
+    ret = secp256k1_ec_seckey_tweak_add(ctx, key, msg);
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret == 1);
+
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    VALGRIND_MAKE_MEM_UNDEFINED(msg, 32);
+    ret = secp256k1_ec_seckey_tweak_mul(ctx, key, msg);
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret == 1);
+
+    /* Test context randomisation. Do this last because it leaves the context tainted. */
+    VALGRIND_MAKE_MEM_UNDEFINED(key, 32);
+    ret = secp256k1_context_randomize(ctx, key);
+    VALGRIND_MAKE_MEM_DEFINED(&ret, sizeof(ret));
+    CHECK(ret);
+
+    secp256k1_context_destroy(ctx);
+    return 0;
+}
diff --git a/crypto/secp256k1/secp256.go b/crypto/secp256k1/secp256.go
index 8d5ba4bed..8990da6c9 100644
--- a/crypto/secp256k1/secp256.go
+++ b/crypto/secp256k1/secp256.go
@@ -9,10 +9,19 @@ package secp256k1
 #cgo CFLAGS: -I./libsecp256k1
 #cgo CFLAGS: -I./libsecp256k1/src/
 #define USE_NUM_NONE
-#define USE_FIELD_10X26
 #define USE_FIELD_INV_BUILTIN
-#define USE_SCALAR_8X32
 #define USE_SCALAR_INV_BUILTIN
+#if defined(__x86_64__)
+#define USE_FIELD_5X52
+#define USE_SCALAR_4X64
+#define HAVE___INT128
+#else
+#define USE_FIELD_10X26
+#define USE_SCALAR_8X32
+#endif
+#define ECMULT_WINDOW_SIZE 15
+#define ECMULT_GEN_PREC_BITS 4
+#define USE_ENDOMORPHISM
 #define NDEBUG
 #include "./libsecp256k1/src/secp256k1.c"
 #include "./libsecp256k1/src/modules/recovery/main_impl.h"
