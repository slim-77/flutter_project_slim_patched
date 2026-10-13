"""يفعّل desugaring في ملف gradle (مطلوب لمكتبة الإشعارات)."""
import pathlib
import re
import sys

groovy = pathlib.Path('android/app/build.gradle')
kts = pathlib.Path('android/app/build.gradle.kts')
LIB = 'com.android.tools:desugar_jdk_libs:2.0.4'

if groovy.exists():
    s = groovy.read_text()
    if 'coreLibraryDesugaringEnabled' not in s:
        s, n = re.subn(r'compileOptions\s*\{',
                       'compileOptions {\n        coreLibraryDesugaringEnabled true',
                       s, count=1)
        if n != 1:
            sys.exit('compileOptions block not found in build.gradle')
        s += f"\ndependencies {{\n    coreLibraryDesugaring '{LIB}'\n}}\n"
        groovy.write_text(s)
elif kts.exists():
    s = kts.read_text()
    if 'isCoreLibraryDesugaringEnabled' not in s:
        s, n = re.subn(r'compileOptions\s*\{',
                       'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
                       s, count=1)
        if n != 1:
            sys.exit('compileOptions block not found in build.gradle.kts')
        s += f'\ndependencies {{\n    coreLibraryDesugaring("{LIB}")\n}}\n'
        kts.write_text(s)
else:
    sys.exit('no android/app/build.gradle(.kts) found')
print('desugaring enabled')
