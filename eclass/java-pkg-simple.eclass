# Copyright 2004-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: java-pkg-simple.eclass
# @MAINTAINER:
# java@gentoo.org
# @AUTHOR:
# Java maintainers <java@gentoo.org>
# @SUPPORTED_EAPIS: 8
# @BLURB: Eclass for packaging Java software with ease.
# @DESCRIPTION:
# This class is intended to build pure Java packages from Java sources
# without the use of any build instructions shipped with the sources.
# It can generate module-info.java files and supports adding the Main-Class
# and the Automatic-Module-Name attributes to MANIFEST.MF. There is no
# further support for generating source files, or for controlling
# the META-INF of the resulting jar, although these issues may be
# addressed by an ebuild by putting corresponding files into the target
# directory before calling the src_compile function of this eclass.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_JAVA_PKG_SIMPLE_ECLASS} ]] ; then
_JAVA_PKG_SIMPLE_ECLASS=1

inherit java-utils-2

if has java-pkg-2 ${INHERITED}; then
	JAVA_PKG_OPT=0
elif has java-pkg-opt-2 ${INHERITED}; then
	JAVA_PKG_OPT=1
else
	eerror "java-pkg-simple eclass can only be inherited AFTER java-pkg-2 or java-pkg-opt-2"
fi

# We are only interested in finding all java source files, wherever they may be.
S="${WORKDIR}"

# handle dependencies for testing frameworks
if has test ${JAVA_PKG_IUSE}; then
	test_deps=
	for framework in ${JAVA_TESTING_FRAMEWORKS}; do
		case ${framework} in
			junit)
				test_deps+=" dev-java/junit:0";;
			junit-4)
				test_deps+=" dev-java/junit:4";;
			pkgdiff)
				test_deps+=" amd64? ( dev-util/pkgdiff
					dev-util/japi-compliance-checker )";;
			testng)
				[[ ${PN} != testng ]] && \
					test_deps+=" dev-java/testng:0";;
		esac
	done
	if [[ ${JAVA_PKG_OPT} == 1 ]]; then
		[[ ${test_deps} ]] && DEPEND="test? ( ${JAVA_PKG_OPT_USE}? ( ${test_deps} ) )"
	else
		[[ ${test_deps} ]] && DEPEND="test? ( ${test_deps} )"
	fi

	unset test_deps
fi

# @ECLASS_VARIABLE: JAVA_GENTOO_CLASSPATH
# @DEFAULT_UNSET
# @DESCRIPTION:
# Comma or space separated list of java packages to include in the
# class path. The packages will also be registered as runtime
# dependencies of this new package. Dependencies will be calculated
# transitively. See "java-config -l" for appropriate package names.
#
# @CODE
#	JAVA_GENTOO_CLASSPATH="foo,bar-2"
# @CODE

# @ECLASS_VARIABLE: JAVA_GENTOO_CLASSPATH_EXTRA
# @DEFAULT_UNSET
# @DESCRIPTION:
# Extra list of colon separated path elements to be put on the
# classpath when compiling sources.

# @ECLASS_VARIABLE: JAVA_CLASSPATH_EXTRA
# @DEFAULT_UNSET
# @DESCRIPTION:
# An extra comma or space separated list of java packages
# that are needed only during compiling sources.

# @ECLASS_VARIABLE: JAVA_NEEDS_TOOLS
# @DEFAULT_UNSET
# @DESCRIPTION:
# Add tools.jar to the gentoo.classpath. Should only be used
# for build-time purposes, the dependency is not recorded to
# package.env.

# @ECLASS_VARIABLE: JAVA_SRC_DIR
# @DEFAULT_UNSET
# @DESCRIPTION:
# An array of directories relative to ${S} which contain the sources
# of the application. If you set ${JAVA_SRC_DIR} to a string it works
# as well. The default value "" means it will get all source files
# inside ${S}.
# For the generated source package (if source is listed in
# ${JAVA_PKG_IUSE}), it is important that these directories are
# actually the roots of the corresponding source trees.
#
# @CODE
#	JAVA_SRC_DIR=( "impl/src/main/java/"
#		"arquillian/weld-ee-container/src/main/java/"
#	)
# @CODE

# @ECLASS_VARIABLE: JAVA_RESOURCE_DIRS
# @DEFAULT_UNSET
# @DESCRIPTION:
# An array of directories relative to ${S} which contain the
# resources of the application. If you do not set the variable,
# there will be no resources added to the compiled jar file.
#
# @CODE
#	JAVA_RESOURCE_DIRS=("src/java/resources/")
# @CODE

# @ECLASS_VARIABLE: JAVA_ENCODING
# @DESCRIPTION:
# The character encoding used in the source files.
: "${JAVA_ENCODING:=UTF-8}"

# @ECLASS_VARIABLE: JAVAC_ARGS
# @DEFAULT_UNSET
# @DESCRIPTION:
# Additional arguments to be passed to javac.

# @ECLASS_VARIABLE: JAVA_MAIN_CLASS
# @DEFAULT_UNSET
# @DESCRIPTION:
# If the java has a main class, you are going to set the
# variable so that we can generate a proper MANIFEST.MF
# and create a launcher.
#
# @CODE
#	JAVA_MAIN_CLASS="org.gentoo.java.ebuilder.Main"
# @CODE

# @ECLASS_VARIABLE: JAVA_AUTOMATIC_MODULE_NAME
# @DEFAULT_UNSET
# @DESCRIPTION:
# The value of the Automatic-Module-Name entry, which is going to be added to
# MANIFEST.MF.

# @ECLASS_VARIABLE: JAVADOC_ARGS
# @DEFAULT_UNSET
# @DESCRIPTION:
# Additional arguments to be passed to javadoc.

# @ECLASS_VARIABLE: JAVA_JAR_FILENAME
# @DESCRIPTION:
# The name of the jar file to create and install.
: "${JAVA_JAR_FILENAME:=${PN}.jar}"

# @ECLASS_VARIABLE: JAVA_BINJAR_FILENAME
# @DEFAULT_UNSET
# @DESCRIPTION:
# The name of the binary jar file to be installed if
# USE FLAG 'binary' is set.

# @ECLASS_VARIABLE: JAVA_LAUNCHER_FILENAME
# @DESCRIPTION:
# If ${JAVA_MAIN_CLASS} is set, we will create a launcher to
# execute the jar, and ${JAVA_LAUNCHER_FILENAME} will be the
# name of the script.
if [[ ${SLOT} = 0 ]]; then
	: "${JAVA_LAUNCHER_FILENAME:=${PN}}"
else
	: "${JAVA_LAUNCHER_FILENAME:=${PN}-${SLOT}}"
fi

# @ECLASS_VARIABLE: JAVA_TESTING_FRAMEWORKS
# @DEFAULT_UNSET
# @DESCRIPTION:
# A space separated list that defines which tests it should launch
# during src_test.
#
# @CODE
# JAVA_TESTING_FRAMEWORKS="junit pkgdiff"
# @CODE

# @ECLASS_VARIABLE: JAVA_TEST_RUN_ONLY
# @DEFAULT_UNSET
# @DESCRIPTION:
# A array of classes that should be executed during src_test(). This variable
# has precedence over JAVA_TEST_EXCLUDES, that is if this variable is set,
# the other variable is ignored.
#
# @CODE
# JAVA_TEST_RUN_ONLY=( "net.sf.cglib.AllTests" "net.sf.cglib.TestAll" )
# @CODE

# @ECLASS_VARIABLE: JAVA_TEST_EXCLUDES
# @DEFAULT_UNSET
# @DESCRIPTION:
# A array of classes that should not be executed during src_test().
#
# @CODE
# JAVA_TEST_EXCLUDES=( "net.sf.cglib.CodeGenTestCase" "net.sf.cglib.TestAll" )
# @CODE

# @ECLASS_VARIABLE: JAVA_TEST_GENTOO_CLASSPATH
# @DEFAULT_UNSET
# @DESCRIPTION:
# The extra classpath we need while compiling and running the
# source code for testing.

# @ECLASS_VARIABLE: JAVA_TEST_SRC_DIR
# @DEFAULT_UNSET
# @DESCRIPTION:
# An array of directories relative to ${S} which contain the
# sources for testing. It is almost equivalent to
# ${JAVA_SRC_DIR} in src_test.

# @ECLASS_VARIABLE: JAVA_TEST_RESOURCE_DIRS
# @DEFAULT_UNSET
# @DESCRIPTION:
# It is almost equivalent to ${JAVA_RESOURCE_DIRS} in src_test.

# @ECLASS_VARIABLE: JAVA_INTERMEDIATE_JAR_NAME
# @DEFAULT_UNSET
# @DESCRIPTION:
# Name of the intermediate jar file excluding the '.jar' suffix and also name of the
# ejavac output directory which are needed by 'jdeps --generate-module-info'.
# @CODE
# Examples:
# 	JAVA_INTERMEDIATE_JAR_NAME="org.apache.${PN/-/.}"
# 	JAVA_INTERMEDIATE_JAR_NAME="com.github.marschall.memoryfilesystem"
# @CODE

# @ECLASS_VARIABLE: JAVA_MODULE_INFO_OUT
# @DEFAULT_UNSET
# @DESCRIPTION:
# Used by java-pkg-simple_generate-module-info.
# It is the directory where module-info.java will be created.
# Only when this variable is set, module-info.java will be created.
# @CODE
# Example:
# 	JAVA_MODULE_INFO_OUT="src/main"
# @CODE

# @ECLASS_VARIABLE: JAVA_MODULE_INFO_RELEASE
# @DESCRIPTION:
# Used by java-pkg-simple_generate-module-info.
# Correlates to JAVA_RELEASE_SRC_DIRS.
# When this variable is set, module-info.java will be placed in
# ${JAVA_MODULE_INFO_OUT}/${JAVA_INTERMEDIATE_JAR_NAME}/versions/${JAVA_MODULE_INFO_RELEASE}

# @ECLASS_VARIABLE: JAVA_RELEASE_SRC_DIRS
# @DEFAULT_UNSET
# @DESCRIPTION:
# An associative array of directories with release-specific sources which are
# used for building multi-release jar files.
# @CODE
# Example:
#	JAVA_RELEASE_SRC_DIRS=(
#		["9"]="prov/src/main/jdk1.9"
#		["11"]="prov/src/main/jdk1.11"
#		["15"]="prov/src/main/jdk1.15"
#		["21"]="prov/src/main/jdk21"
#	)
# @CODE

# @FUNCTION: java-pkg-simple_getclasspath
# @USAGE: java-pkg-simple_getclasspath
# @INTERNAL
# @DESCRIPTION:
# Get proper ${classpath} from ${JAVA_GENTOO_CLASSPATH_EXTRA},
# ${JAVA_NEEDS_TOOLS}, ${JAVA_CLASSPATH_EXTRA} and
# ${JAVA_GENTOO_CLASSPATH}. We use it inside
# java-pkg-simple_src_compile and java-pkg-simple_src_test.
#
# Note that the variable "classpath" needs to be defined before
# calling this function.
java-pkg-simple_getclasspath() {
	debug-print-function ${FUNCNAME} $*

	local dependency
	local deep_jars="--with-dependencies"
	local buildonly_jars="--build-only"

	# the extra classes that are not installed by portage
	classpath+=":${JAVA_GENTOO_CLASSPATH_EXTRA}"

	# whether we need tools.jar
	[[ ${JAVA_NEEDS_TOOLS} ]] && classpath+=":$(java-config --tools)"

	# the extra classes that are installed by portage
	for dependency in ${JAVA_CLASSPATH_EXTRA}; do
		classpath="${classpath}:$(java-pkg_getjars ${buildonly_jars}\
			${deep_jars} ${dependency})"
	done

	# add test dependencies if USE FLAG 'test' is set
	if has test ${JAVA_PKG_IUSE} && use test; then
		for dependency in ${JAVA_TEST_GENTOO_CLASSPATH}; do
			classpath="${classpath}:$(java-pkg_getjars ${buildonly_jars}\
				${deep_jars} ${dependency})"
		done
	fi

	# add the RUNTIME dependencies
	for dependency in ${JAVA_GENTOO_CLASSPATH}; do
		classpath="${classpath}:$(java-pkg_getjars ${deep_jars} ${dependency})"
	done

	# purify classpath
	while [[ $classpath = *::* ]]; do classpath="${classpath//::/:}"; done
	classpath=${classpath%:}
	classpath=${classpath#:}

	debug-print "CLASSPATH=${classpath}"
}

# @FUNCTION: java-pkg-simple_getmodulepath
# @USAGE: java-pkg-simple_getmodulepath
# @INTERNAL
# @DESCRIPTION:
# Cloned from java-pkg-simple_getclasspath, dropped 'deep_jars'
# and replaced s/classpath/modulepath/g.
#
# It is needed for java-pkg-simple_generate-module-info where using classpath
# would cause problems with '--with-dependencies'.
# And it is also used for compilation.
#
# Note that the variable "modulepath" needs to be defined before
# calling this function.
java-pkg-simple_getmodulepath() {
	debug-print-function ${FUNCNAME} $*

	local dependency
	local buildonly_jars="--build-only"

	# the extra classes that are not installed by portage
	modulepath+=":${JAVA_GENTOO_CLASSPATH_EXTRA}"

	# the extra classes that are installed by portage
	for dependency in ${JAVA_CLASSPATH_EXTRA}; do
		modulepath="${modulepath}:$(java-pkg_getjars ${buildonly_jars} \
			${dependency})"
	done

	# add test dependencies if USE FLAG 'test' is set
	if has test ${JAVA_PKG_IUSE} && use test; then
		for dependency in ${JAVA_TEST_GENTOO_CLASSPATH}; do
			modulepath="${modulepath}:$(java-pkg_getjars ${buildonly_jars} \
				${dependency})"
		done
	fi

	# add the RUNTIME dependencies
	for dependency in ${JAVA_GENTOO_CLASSPATH}; do
		modulepath="${modulepath}:$(java-pkg_getjars ${dependency})"
	done

	# purify modulepath
	while [[ $modulepath = *::* ]]; do modulepath="${modulepath//::/:}"; done
	modulepath=${modulepath%:}
	modulepath=${modulepath#:}

	debug-print "modulepath=${modulepath}"
}

# @FUNCTION: java-pkg-simple_generate-module-info
# @USAGE: java-pkg-simple_generate-module-info
# @INTERNAL
# @DESCRIPTION:
# Calls jdeps --generate-module-info which generates module-info.java.
# Requires an intermediate jar file to be named as "${JAVA_INTERMEDIATE_JAR_NAME}.jar".
java-pkg-simple_generate-module-info() {
	debug-print-function ${FUNCNAME} $*

	local modulepath="" jdeps_args=""
	java-pkg-simple_getmodulepath

	# Default to release 9 in order to avoid having to set it in the ebuild.
	: "${JAVA_MODULE_INFO_RELEASE:=9}"

	if [[ ${JAVA_MODULE_INFO_RELEASE} ]]; then
		jdeps_args="${jdeps_args} --multi-release ${JAVA_MODULE_INFO_RELEASE}"
	fi

	if [[ ${modulepath} ]]; then
		jdeps_args="${jdeps_args} --module-path ${modulepath}"
		jdeps_args="${jdeps_args} --add-modules=ALL-MODULE-PATH"
	fi
	debug-print "jdeps_args is ${jdeps_args}"

	jdeps \
		--generate-module-info "${JAVA_MODULE_INFO_OUT}" \
		${jdeps_args} \
		"${JAVA_INTERMEDIATE_JAR_NAME}.jar" || die

	moduleinfo=$(find -type f -name module-info.java)
}

# @FUNCTION: java-pkg-simple_test_with_pkgdiff_
# @INTERNAL
# @DESCRIPTION:
# use japi-compliance-checker the ensure the compabitily of \*.class files,
# Besides, use pkgdiff to ensure the compatibility of resources.
java-pkg-simple_test_with_pkgdiff_() {
	debug-print-function ${FUNCNAME} $*

	if [[ ! ${ARCH} == "amd64" ]]; then
		elog "For architectures other than amd64, "\
			"the pkgdiff test is currently unavailable "\
			"because 'dev-util/japi-compliance-checker "\
			"and 'dev-util/pkgdiff' do not support those architectures."
		return
	fi

	local report1=${PN}-japi-compliance-checker.html
	local report2=${PN}-pkgdiff.html

	# pkgdiff test
	if [[ -f "${DISTDIR}/${JAVA_BINJAR_FILENAME}" ]]; then
		# pkgdiff cannot deal with symlinks, so this is a workaround
		cp "${DISTDIR}/${JAVA_BINJAR_FILENAME}" ./ \
			|| die "Cannot copy binjar file to ${S}."

		# japi-compliance-checker
		japi-compliance-checker ${JAVA_BINJAR_FILENAME} ${JAVA_JAR_FILENAME}\
			--lib=${PN} -v1 ${PV}-bin -v2 ${PV} -report-path ${report1}\
			--binary\
			|| die "japi-compliance-checker returns $?,"\
				"check the report in ${S}/${report1}"

		# ignore META-INF since it does not matter
		# ignore classes because japi-compilance checker will take care of it
		pkgdiff ${JAVA_BINJAR_FILENAME} ${JAVA_JAR_FILENAME}\
			-vnum1 ${PV}-bin -vnum2 ${PV}\
			-skip-pattern "META-INF|.class$"\
			-name ${PN} -report-path ${report2}\
			|| die "pkgdiff returns $?, check the report in ${S}/${report2}"
	fi
}

# @FUNCTION: java-pkg-simple_prepend_resources
# @USAGE: java-pkg-simple_prepend-resources <${classes}> <"${RESOURCE_DIRS[@]}">
# @INTERNAL
# @DESCRIPTION:
# Copy things under "${JAVA_RESOURCE_DIRS[@]}" or "${JAVA_TEST_RESOURCE_DIRS[@]}"
# to ${classes}, so that `jar` will package resources together with classes.
#
# Note that you need to define a "classes" variable before calling
# this function.
java-pkg-simple_prepend_resources() {
	debug-print-function ${FUNCNAME} $*

	local destination="${1}"
	shift 1

	# return if there is no resource dirs defined
	[[ "$@" ]] || return
	local resources=("${@}")

	# add resources directory to classpath
	for resource in "${resources[@]}"; do
		cp -rT "${resource:-.}" "${destination}"\
			|| die "Could not copy resources from ${resource:-.} to ${destination}"
	done
}

# @FUNCTION: java-pkg-simple_src_compile
# @DESCRIPTION:
# src_compile for simple bare source java packages. Finds all *.java
# sources in ${JAVA_SRC_DIR}, compiles them with the classpath
# calculated from ${JAVA_GENTOO_CLASSPATH}, and packages the resulting
# classes to a single ${JAVA_JAR_FILENAME}. If the file
# target/META-INF/MANIFEST.MF exists, it is used as the manifest of the
# created jar.
#
# If USE FLAG 'binary' exists and is set, it will just copy
# ${JAVA_BINJAR_FILENAME} to ${S} and skip the rest of src_compile.
java-pkg-simple_src_compile() {
	[[ ${JAVA_PKG_OPT} == 1 ]] && ! use ${JAVA_PKG_OPT_USE} && return
	local sources=sources.lst classes=target/classes apidoc=target/api moduleinfo

	# do not compile if we decide to install binary jar
	if has binary ${JAVA_PKG_IUSE} && use binary; then
		# register the runtime dependencies
		for dependency in ${JAVA_GENTOO_CLASSPATH//,/ }; do
			java-pkg_record-jar_ ${dependency}
		done

		cp "${DISTDIR}"/${JAVA_BINJAR_FILENAME} ${JAVA_JAR_FILENAME}\
			|| die "Could not copy the binary jar file to ${S}"
		return 0
	else
		# auto generate classpath
		java-pkg_gen-cp JAVA_GENTOO_CLASSPATH
	fi

	# generate module-info.java only if JAVA_MODULE_INFO_OUT is defined in the ebuild
	if [[ ${JAVA_MODULE_INFO_OUT} && ${JAVA_INTERMEDIATE_JAR_NAME} ]]; then

		local jdk="$(depend-java-query --get-lowest "${DEPEND}")"
		if [[ "${jdk#1.}" -lt 9 ]]; then
			die "Wrong DEPEND, needs at least virtual/jdk-9"
		fi

		local classpath=""
		java-pkg-simple_getclasspath

		# gather sources and compile classes for the intermediate jar file
		find "${JAVA_SRC_DIR[@]}" -name \*.java ! -name module-info.java > ${sources}
		ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
			${classpath:+-classpath ${classpath}} ${JAVAC_ARGS} @${sources}

		java-pkg-simple_prepend_resources ${classes} "${JAVA_RESOURCE_DIRS[@]}"

		# package the intermediate jar file
		# The intermediate jar file is a precondition for jdeps to generate
		# a module-info.java file.
		jar cvf "${JAVA_INTERMEDIATE_JAR_NAME}.jar" \
			-C target/classes . || die

		# now, generate module-info.java
		java-pkg-simple_generate-module-info
		debug-print "generated moduleinfo is ${moduleinfo}"

		# If JAVA_RELEASE_SRC_DIRS was not set in the ebuild, set it now:
		if [[ ${JAVA_MODULE_INFO_RELEASE} && -z ${JAVA_RELEASE_SRC_DIRS[@]} ]]; then
			# TODO: use JAVA_MODULE_INFO_RELEASE instead of fixed value.
			JAVA_RELEASE_SRC_DIRS=( ["9"]=${JAVA_MODULE_INFO_OUT}/${JAVA_INTERMEDIATE_JAR_NAME}"/versions/9" )
		fi
	fi

	# JEP 238 multi-release support, https://openjdk.org/jeps/238 #900433
	#
	# Basic support for building multi-release jar files according to JEP 238.
	# A multi-release jar file has release-specific classes in directories
	# under META-INF/versions/.
	# Its META-INF/MANIFEST.MF contains the line: 'Multi-Release: true'.
	if [[ -n ${JAVA_RELEASE_SRC_DIRS[@]} ]]; then
		# Ensure correct virtual/jdk version
		# Initialize a variable to track the highest key
		local highest_version=-1

		# Loop through the keys of the associative array
		for key in "${!JAVA_RELEASE_SRC_DIRS[@]}"; do
		    # Compare the numeric value of the key
		    if [[ key -gt highest_version ]]; then
		        highest_version="$key"
		    fi
		done

		local jdk="$(depend-java-query --get-lowest "${DEPEND}")"
		if [[ "${jdk#1.}" -lt "${highest_version}" ]]; then
			die "Wrong DEPEND, needs at least virtual/jdk-${highest_version}"
		fi

		local classpath=""
		java-pkg-simple_getclasspath

		# An intermediate jar file might already exist from generation of the
		# module-info.java file
		if [[ ! $(find . -name ${JAVA_INTERMEDIATE_JAR_NAME}.jar) ]]; then
			einfo "generating intermediate for multi-release"
			# gather sources and compile classes for the intermediate jar file
			find "${JAVA_SRC_DIR[@]}" -name \*.java ! -name module-info.java > ${sources}
			ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
				${classpath:+-classpath ${classpath}} ${JAVAC_ARGS} @${sources}

			java-pkg-simple_prepend_resources ${classes} "${JAVA_RESOURCE_DIRS[@]}"

			# package the intermediate jar file
			# The intermediate jar file is a precondition for jdeps to generate
			# a module-info.java file.
			jar cvf "${JAVA_INTERMEDIATE_JAR_NAME}.jar" \
				-C target/classes . || die
		fi

		local tmp_source=${JAVA_PKG_WANT_SOURCE} tmp_target=${JAVA_PKG_WANT_TARGET}

		# compile content of release-specific source directories
		local version
		for version in "${!JAVA_RELEASE_SRC_DIRS[@]}"; do
			local release="${version}"
			local reldir="${JAVA_RELEASE_SRC_DIRS[${version}]}"
			debug-print "Release is ${release}, directory is ${reldir}"

			JAVA_PKG_WANT_SOURCE="${release}"
			JAVA_PKG_WANT_TARGET="${release}"

			local modulepath=""
			java-pkg-simple_getmodulepath

			# compile sources in ${reldir}
			ejavac \
				-d target/versions/${release} \
				-encoding ${JAVA_ENCODING} \
				-classpath "${modulepath}:${JAVA_INTERMEDIATE_JAR_NAME}.jar" \
				--module-path "${modulepath}:${JAVA_INTERMEDIATE_JAR_NAME}.jar" \
				--module-version ${PV} \
				--patch-module "${JAVA_INTERMEDIATE_JAR_NAME}"="${JAVA_INTERMEDIATE_JAR_NAME}.jar" \
				${JAVAC_ARGS} $(find ${reldir} -type f -name '*.java')

			JAVA_GENTOO_CLASSPATH_EXTRA+=":target/versions/${release}"
		done

		JAVA_PKG_WANT_SOURCE=${tmp_source}
		JAVA_PKG_WANT_TARGET=${tmp_target}
	else
		# gather sources
		# if target < 9, we need to compile module-info.java separately
		# as this feature is not supported before Java 9
		local target="$(java-pkg_get-target)"
		if [[ ${target#1.} -lt 9 ]]; then
			find "${JAVA_SRC_DIR[@]}" -name \*.java ! -name module-info.java > ${sources}
		else
			find "${JAVA_SRC_DIR[@]}" -name \*.java > ${sources}
		fi
		moduleinfo=$(find "${JAVA_SRC_DIR[@]}" -name module-info.java)

		# create the target directory
		mkdir -p ${classes} || die "Could not create target directory"

		# compile
		local classpath=""
		java-pkg-simple_getclasspath
		java-pkg-simple_prepend_resources ${classes} "${JAVA_RESOURCE_DIRS[@]}"

		if [[ -z ${moduleinfo} ]] || [[ ${target#1.} -lt 9 ]]; then
			ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
				${classpath:+-classpath ${classpath}} ${JAVAC_ARGS} @${sources}
		else
			ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
				${classpath:+--module-path ${classpath}} --module-version ${PV}\
				${JAVAC_ARGS} @${sources}
		fi

		# handle module-info.java separately as it needs at least JDK 9
		if [[ -n ${moduleinfo} ]] && [[ ${target#1.} -lt 9 ]]; then
			if java-pkg_is-vm-version-ge "9" ; then
				local tmp_source=${JAVA_PKG_WANT_SOURCE} tmp_target=${JAVA_PKG_WANT_TARGET}

				JAVA_PKG_WANT_SOURCE="9"
				JAVA_PKG_WANT_TARGET="9"
				ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
					${classpath:+--module-path ${classpath}} --module-version ${PV}\
					${JAVAC_ARGS} "${moduleinfo}"

				JAVA_PKG_WANT_SOURCE=${tmp_source}
				JAVA_PKG_WANT_TARGET=${tmp_target}
			else
				eqawarn "QA Notice: Need at least JDK 9 to compile module-info.java in src_compile."
				eqawarn "Please adjust DEPEND accordingly. See https://bugs.gentoo.org/796875#c3"
			fi
		fi
	fi

	# javadoc
	if has doc ${JAVA_PKG_IUSE} && use doc; then
		if [[ ${JAVADOC_SRC_DIRS} ]]; then
			einfo "JAVADOC_SRC_DIRS exists, you need to call ejavadoc separately"
		else
			mkdir -p ${apidoc}
			if [[ -z ${moduleinfo} ]] || [[ ${target#1.} -lt 9 ]]; then
				ejavadoc -d ${apidoc} \
					-encoding ${JAVA_ENCODING} -docencoding UTF-8 -charset UTF-8 \
					${classpath:+-classpath ${classpath}} ${JAVADOC_ARGS:- -quiet} \
					@${sources} || die "javadoc failed"
			else
				ejavadoc -d ${apidoc} \
					-encoding ${JAVA_ENCODING} -docencoding UTF-8 -charset UTF-8 \
					${classpath:+--module-path ${classpath}} ${JAVADOC_ARGS:- -quiet} \
					@${sources} || die "javadoc failed"
			fi
		fi
	fi

	# package
	local jar_args multi_release=""
	if [[ -n ${JAVA_RELEASE_SRC_DIRS[@]} ]]; then
		# Preparing the multi_release variable. From multi-release compilation
		# the release-specific classes are sorted in target/versions/${release}
		# directories.

		# TODO:
		# Could this possibly be simplified with printf?
		pushd target/versions > /dev/null || die
			for version in $(ls -d * | sort -g); do
				debug-print "Version is ${version}"
				multi_release="${multi_release} --release ${version} -C target/versions/${version} . "
			done
		popd > /dev/null || die
	fi

	if [[ -e ${classes}/META-INF/MANIFEST.MF ]]; then
		sed '/Created-By: /Id' -i ${classes}/META-INF/MANIFEST.MF
		jar_args="cfm ${JAVA_JAR_FILENAME} ${classes}/META-INF/MANIFEST.MF"
	else
		jar_args="cf ${JAVA_JAR_FILENAME}"
	fi
	jar ${jar_args} -C ${classes} . ${multi_release} || die "jar failed"
	if  [[ -n "${JAVA_AUTOMATIC_MODULE_NAME}" ]]; then
		echo "Automatic-Module-Name: ${JAVA_AUTOMATIC_MODULE_NAME}" \
			>> "${T}/add-to-MANIFEST.MF" || die "adding module name failed"
	fi
	if  [[ -n "${JAVA_MAIN_CLASS}" ]]; then
		echo "Main-Class: ${JAVA_MAIN_CLASS}" \
			>> "${T}/add-to-MANIFEST.MF" || die "adding main class failed"
	fi
	if [[ -f "${T}/add-to-MANIFEST.MF" ]]; then
		jar ufmv ${JAVA_JAR_FILENAME} "${T}/add-to-MANIFEST.MF" \
			|| die "updating MANIFEST.MF failed"
		rm -f "${T}/add-to-MANIFEST.MF" || die "cannot remove"
	fi

	unset JAVA_INTERMEDIATE_JAR_NAME
	unset JAVA_MODULE_INFO_OUT
	unset JAVA_MODULE_INFO_RELEASE
	unset JAVA_RELEASE_SRC_DIRS
}

# @FUNCTION: java-pkg-simple_src_install
# @DESCRIPTION:
# src_install for simple single jar java packages. Simply installs
# ${JAVA_JAR_FILENAME}. It will also install a launcher if
# ${JAVA_MAIN_CLASS} is set. Also invokes einstalldocs.
java-pkg-simple_src_install() {
	[[ ${JAVA_PKG_OPT} == 1 ]] && ! use ${JAVA_PKG_OPT_USE} && return
	local sources=sources.lst classes=target/classes apidoc=target/api

	# install the jar file that we need
	java-pkg_dojar ${JAVA_JAR_FILENAME}

	# install a wrapper if ${JAVA_MAIN_CLASS} is defined
	if [[ ${JAVA_MAIN_CLASS} ]]; then
		java-pkg_dolauncher "${JAVA_LAUNCHER_FILENAME}" --main ${JAVA_MAIN_CLASS}
	fi

	# javadoc
	if has doc ${JAVA_PKG_IUSE} && use doc; then
		java-pkg_dojavadoc ${apidoc}
	fi

	# dosrc
	if has source ${JAVA_PKG_IUSE} && use source; then
		local srcdirs=""
		if [[ "${JAVA_SRC_DIR[@]}" ]]; then
			local parent child
			for parent in "${JAVA_SRC_DIR[@]}"; do
				srcdirs="${srcdirs} ${parent}"
			done
		else
			# take all directories actually containing any sources
			srcdirs="$(cut -d/ -f1 ${sources} | sort -u)"
		fi
		java-pkg_dosrc ${srcdirs}
	fi

	einstalldocs
}

# @FUNCTION: java-pkg-simple_src_test
# @DESCRIPTION:
# src_test for simple single java jar file.
# It will compile test classes from test sources using ejavac and perform tests
# with frameworks that are defined in ${JAVA_TESTING_FRAMEWORKS}.
# test-classes compiled with alternative compilers like groovyc need to be placed
# in the "generated-test" directory as content of this directory is preserved,
# whereas content of target/test-classes is removed.
java-pkg-simple_src_test() {
	[[ ${JAVA_PKG_OPT} == 1 ]] && ! use ${JAVA_PKG_OPT_USE} && return
	local test_sources=test_sources.lst classes=target/test-classes moduleinfo
	local tests_to_run classpath

	# do not continue if the USE FLAG 'test' is explicitly unset
	# or no ${JAVA_TESTING_FRAMEWORKS} is specified
	if ! has test ${JAVA_PKG_IUSE}; then
		return
	elif ! use test; then
		return
	elif [[ ! "${JAVA_TESTING_FRAMEWORKS}" ]]; then
		return
	fi

	# https://bugs.gentoo.org/906311
	# This will remove target/test-classes. Do not put any test-classes there manually.
	rm -rf ${classes} || die

	# create the target directory
	mkdir -p ${classes} || die "Could not create target directory for testing"

	# generated test classes should get compiled into "generated-test" directory
	if [[ -d generated-test ]]; then
		cp -r generated-test/* "${classes}" || die "cannot copy generated test classes"
	fi

	# get classpath
	classpath="${classes}:${JAVA_JAR_FILENAME}"
	java-pkg-simple_getclasspath
	java-pkg-simple_prepend_resources ${classes} "${JAVA_TEST_RESOURCE_DIRS[@]}"

	# gathering sources for testing
	# if target < 9, we need to compile module-info.java separately
	# as this feature is not supported before Java 9
	local target="$(java-pkg_get-target)"
	if [[ ${target#1.} -lt 9 ]]; then
		find "${JAVA_TEST_SRC_DIR[@]}" -name \*.java ! -name module-info.java > ${test_sources}
	else
		find "${JAVA_TEST_SRC_DIR[@]}" -name \*.java > ${test_sources}
	fi
	moduleinfo=$(find "${JAVA_TEST_SRC_DIR[@]}" -name module-info.java)

	# compile
	if [[ -s ${test_sources} ]]; then
		if [[ -z ${moduleinfo} ]] || [[ ${target#1.} -lt 9 ]]; then
			ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
				${classpath:+-classpath ${classpath}} ${JAVAC_ARGS} @${test_sources}
		else
			ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
				${classpath:+--module-path ${classpath}} --module-version ${PV}\
				${JAVAC_ARGS} @${test_sources}
		fi
	fi

	# handle module-info.java separately as it needs at least JDK 9
	if [[ -n ${moduleinfo} ]] && [[ ${target#1.} -lt 9 ]]; then
		if java-pkg_is-vm-version-ge "9" ; then
			local tmp_source=${JAVA_PKG_WANT_SOURCE} tmp_target=${JAVA_PKG_WANT_TARGET}

			JAVA_PKG_WANT_SOURCE="9"
			JAVA_PKG_WANT_TARGET="9"
			ejavac -d ${classes} -encoding ${JAVA_ENCODING}\
				${classpath:+--module-path ${classpath}} --module-version ${PV}\
				${JAVAC_ARGS} "${moduleinfo}"

			JAVA_PKG_WANT_SOURCE=${tmp_source}
			JAVA_PKG_WANT_TARGET=${tmp_target}
		else
			ewarn "Need at least JDK 9 to compile module-info.java in src_test,"
			ewarn "see https://bugs.gentoo.org/796875"
		fi
	fi

	# grab a set of tests that testing framework will run
	if [[ -n ${JAVA_TEST_RUN_ONLY} ]]; then
		tests_to_run="${JAVA_TEST_RUN_ONLY[@]}"
	else
		tests_to_run=$(find "${classes}" -type f\
			\( -name "*Test.class"\
			-o -name "Test*.class"\
			-o -name "*Tests.class"\
			-o -name "*TestCase.class" \)\
			! -name "*Abstract*"\
			! -name "*BaseTest*"\
			! -name "*TestTypes*"\
			! -name "*TestUtils*"\
			! -name "*\$*")
		tests_to_run=${tests_to_run//"${classes}"\/}
		tests_to_run=${tests_to_run//.class}
		tests_to_run=${tests_to_run//\//.}

		# exclude extra test classes, usually corner cases
		# that the code above cannot handle
		for class in "${JAVA_TEST_EXCLUDES[@]}"; do
			tests_to_run=${tests_to_run//${class}}
		done
	fi

	# launch test
	for framework in ${JAVA_TESTING_FRAMEWORKS}; do
		case ${framework} in
			junit)
				ejunit -classpath "${classpath}" ${tests_to_run};;
			junit-4)
				ejunit4 -classpath "${classpath}" ${tests_to_run};;
			pkgdiff)
				java-pkg-simple_test_with_pkgdiff_;;
			testng)
				etestng -classpath "${classpath}" ${tests_to_run};;
			*)
				elog "No suitable function found for framework ${framework}"
		esac
	done
}

fi

EXPORT_FUNCTIONS src_compile src_install src_test
