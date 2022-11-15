set -e
set +u
### Avoid recursively calling this script.
if [[ $UF_MASTER_SCRIPT_RUNNING ]]
then
exit 0
fi
set -u
export UF_MASTER_SCRIPT_RUNNING=1
### Constants.
# RESOURCE_BUNDLE="AFNetworkHKBinary"
# 静态库target对应的scheme名称
SCHEMENAME="AFNetworkHKBinary"
# .a与头文件生成的目录，在项目中的AFNetworkHKBinary目录下的Products目录中
BASEBUILDDIR=$PWD/${SCHEMENAME}/Products
rm -fr "${BASEBUILDDIR}"
mkdir "${BASEBUILDDIR}"
# 支持全架构的二进制文件目录
UNIVERSAL_OUTPUTFOLDER=${BASEBUILDDIR}/Binary-universal
# 支持真机的二进制文件目录
IPHONE_DEVICE_BUILD_DIR=${BASEBUILDDIR}/Binary-iphoneos
# 支持模拟器的二进制文件目录
IPHONE_SIMULATOR_BUILD_DIR=${BASEBUILDDIR}/Binary-iphonesimulator
### Functions
## List files in the specified directory, storing to the specified array.
#
# @param $1 The path to list
# @param $2 The name of the array to fill
#
##
list_files ()
{
    filelist=$(ls "$1")
    while read line
    do
        eval "$2[\${#$2[*]}]=\"\$line\""
    done <<< "$filelist"
}
### Take build target.
if [[ "$SDK_NAME" =~ ([A-Za-z]+) ]]
then
SF_SDK_PLATFORM=${BASH_REMATCH[1]} # "iphoneos" or "iphonesimulator".
else
echo "Could not find platform name from SDK_NAME: $SDK_NAME"
exit 1
fi
### Build simulator platform. (i386, x86_64)
# echo "========== Build Simulator Platform =========="
# echo "===== Build Simulator Platform: i386 ====="
# xcodebuild -project "${PROJECT_FILE_PATH}" -target "${TARGET_NAME}" -configuration "${CONFIGURATION}" -sdk iphonesimulator BUILD_DIR="${BUILD_DIR}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" CONFIGURATION_BUILD_DIR="${IPHONE_SIMULATOR_BUILD_DIR}/i386" SYMROOT="${SYMROOT}" ARCHS='i386' VALID_ARCHS='i386' $ACTION
echo "===== 构建x86_64架构 ====="
xcodebuild -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${SCHEMENAME}" -configuration "${CONFIGURATION}" -sdk iphonesimulator CONFIGURATION_BUILD_DIR="${IPHONE_SIMULATOR_BUILD_DIR}/x86_64" ARCHS='x86_64' VALID_ARCHS='x86_64' $ACTION
# Build device platform. (armv7, arm64)
echo "========== Build Device Platform =========="
echo "===== Build Device Platform: armv7 ====="
xcodebuild -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${SCHEMENAME}" -configuration "${CONFIGURATION}" -sdk iphoneos CONFIGURATION_BUILD_DIR="${IPHONE_DEVICE_BUILD_DIR}/armv7" ARCHS='armv7 armv7s' VALID_ARCHS='armv7 armv7s' $ACTION
echo "===== Build Device Platform: arm64 ====="
xcodebuild -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${SCHEMENAME}" -configuration "${CONFIGURATION}" -sdk iphoneos CONFIGURATION_BUILD_DIR="${IPHONE_DEVICE_BUILD_DIR}/arm64" ARCHS='arm64' VALID_ARCHS='arm64' $ACTION
### Build universal platform.
echo "========== Build Universal Platform =========="
## Copy the framework structure to the universal folder (clean it first).
rm -rf "${UNIVERSAL_OUTPUTFOLDER}"
mkdir -p "${UNIVERSAL_OUTPUTFOLDER}"
## Copy the last product files of xcodebuild command.
cp -R "${IPHONE_DEVICE_BUILD_DIR}/arm64/lib${SCHEMENAME}.a" "${UNIVERSAL_OUTPUTFOLDER}/lib${SCHEMENAME}.a"
### Smash them together to combine all architectures.
lipo -create "${IPHONE_SIMULATOR_BUILD_DIR}/x86_64/lib${SCHEMENAME}.a" "${IPHONE_DEVICE_BUILD_DIR}/armv7/lib${SCHEMENAME}.a" "${IPHONE_DEVICE_BUILD_DIR}/arm64/lib${SCHEMENAME}.a" -output "${UNIVERSAL_OUTPUTFOLDER}/lib${SCHEMENAME}.a"

echo "========== Create Standard Structure =========="
cp -r "${IPHONE_DEVICE_BUILD_DIR}/arm64/usr/local/include/" "${UNIVERSAL_OUTPUTFOLDER}/include/"
# mkdir -p "${UNIVERSAL_OUTPUTFOLDER}/lib/"
# cp "${UNIVERSAL_OUTPUTFOLDER}/lib${SCHEMENAME}.a" "${UNIVERSAL_OUTPUTFOLDER}/lib/lib${SCHEMENAME}.a"
