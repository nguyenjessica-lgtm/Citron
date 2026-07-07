# SPDX-FileCopyrightText: 2026 citron Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later

include_guard(GLOBAL)

function(citron_build_clangcl_ffmpeg)
    if(NOT DEFINED FFMPEG_CPM_SOURCE_DIR OR
       NOT IS_DIRECTORY "${FFMPEG_CPM_SOURCE_DIR}")
        message(FATAL_ERROR "clang-cl build requires CPM FFmpeg source")
    endif()

    set(CITRON_MSYS2_ROOT "C:/msys64" CACHE PATH "MSYS2 install root")
    find_program(BASH_PROGRAM bash
        HINTS "${CITRON_MSYS2_ROOT}/usr/bin" REQUIRED)
    find_program(MAKE_PROGRAM make
        HINTS "${CITRON_MSYS2_ROOT}/usr/bin" REQUIRED)
    include(ProcessorCount)
    ProcessorCount(_ffmpeg_jobs)
    if(NOT _ffmpeg_jobs)
        set(_ffmpeg_jobs 4)
    endif()

    set(_source_dir "${FFMPEG_CPM_SOURCE_DIR}")
    set(_build_dir "${PROJECT_BINARY_DIR}/externals/ffmpeg-clangcl-build")
    set(_install_dir "${PROJECT_BINARY_DIR}/externals/ffmpeg-clangcl-install")
    get_filename_component(_clangcl_tool_dir "${CMAKE_C_COMPILER}" DIRECTORY)
    get_filename_component(_linker_tool_dir "${CMAKE_LINKER}" DIRECTORY)
    get_filename_component(_ar_tool_dir "${CMAKE_AR}" DIRECTORY)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "MSYS2_ARG_CONV_EXCL=*"
            "${BASH_PROGRAM}" -lc "cygpath -am '${_source_dir}' && cygpath -am '${_build_dir}' && cygpath -am '${_install_dir}' && cygpath -au '${_clangcl_tool_dir}' && cygpath -au '${_linker_tool_dir}' && cygpath -au '${_ar_tool_dir}'"
        OUTPUT_VARIABLE _clangcl_ffmpeg_paths
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(REPLACE "\n" ";" _clangcl_ffmpeg_paths "${_clangcl_ffmpeg_paths}")
    list(GET _clangcl_ffmpeg_paths 0 _source_dir_win)
    list(GET _clangcl_ffmpeg_paths 1 _build_dir_win)
    list(GET _clangcl_ffmpeg_paths 2 _install_dir_win)
    list(GET _clangcl_ffmpeg_paths 3 _clangcl_tool_dir_msys)
    list(GET _clangcl_ffmpeg_paths 4 _linker_tool_dir_msys)
    list(GET _clangcl_ffmpeg_paths 5 _ar_tool_dir_msys)
    set(_build_stamp "${_install_dir}/.built")
    file(MAKE_DIRECTORY "${_build_dir}" "${_install_dir}")
    set(_ffmpeg_configure_command
        "export PATH='${_clangcl_tool_dir_msys}:${_linker_tool_dir_msys}:${_ar_tool_dir_msys}':$PATH &&"
        "'${_source_dir_win}/configure'"
        "--toolchain=msvc"
        "--cc=clang-cl"
        "--cxx=clang-cl"
        "--ld=lld-link"
        "--ar=llvm-ar"
        "--nm=llvm-nm"
        "--prefix='${_install_dir_win}'"
        "--enable-static"
        "--disable-shared"
        "--disable-pthreads"
        "--enable-w32threads"
        "--disable-avdevice"
        "--disable-avformat"
        "--disable-doc"
        "--disable-everything"
        "--disable-ffmpeg"
        "--disable-ffprobe"
        "--disable-network"
        "--disable-swresample"
        "--disable-x86asm"
        "--disable-vaapi"
        "--disable-vdpau"
        "--enable-decoder=h264"
        "--enable-decoder=vp8"
        "--enable-decoder=vp9"
        "--enable-hwaccel=h264_dxva2"
        "--enable-hwaccel=h264_d3d11va"
        "--enable-hwaccel=h264_d3d11va2"
        "--enable-hwaccel=vp9_dxva2"
        "--enable-hwaccel=vp9_d3d11va"
        "--enable-hwaccel=vp9_d3d11va2"
        "--enable-filter=yadif,scale"
        "--enable-dxva2"
        "--enable-d3d11va"
        "--extra-cflags=/MD")
    string(JOIN " " _ffmpeg_configure_command ${_ffmpeg_configure_command})

    add_custom_command(
        OUTPUT "${_build_stamp}"
        BYPRODUCTS
            "${_install_dir}/lib/avfilter.lib"
            "${_install_dir}/lib/swscale.lib"
            "${_install_dir}/lib/avcodec.lib"
            "${_install_dir}/lib/avutil.lib"
        COMMAND "${CMAKE_COMMAND}" -E env "MSYS2_ARG_CONV_EXCL=*"
            "${BASH_PROGRAM}" -lc "${_ffmpeg_configure_command}"
        COMMAND "${CMAKE_COMMAND}" -E env "MSYS2_ARG_CONV_EXCL=*"
            "${BASH_PROGRAM}" -lc "perl -0pi -e 's{(?<![A-Za-z0-9_])/([A-Za-z])/}{uc($1).q{:/}}ge; s{^(AR|AR_CMD)=llvm-lib}{$1=llvm-ar}mg' '${_build_dir_win}/ffbuild/config.mak' '${_build_dir_win}/ffbuild/config.sh'"
        COMMAND "${CMAKE_COMMAND}" -E env "MSYS2_ARG_CONV_EXCL=*"
            "${MAKE_PROGRAM}" -j${_ffmpeg_jobs}
        COMMAND "${CMAKE_COMMAND}" -E env "MSYS2_ARG_CONV_EXCL=*"
            "${MAKE_PROGRAM}" install
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_install_dir_win}/lib"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_install_dir_win}/lib/libavfilter.a" "${_install_dir_win}/lib/avfilter.lib"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_install_dir_win}/lib/libswscale.a" "${_install_dir_win}/lib/swscale.lib"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_install_dir_win}/lib/libavcodec.a" "${_install_dir_win}/lib/avcodec.lib"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_install_dir_win}/lib/libavutil.a" "${_install_dir_win}/lib/avutil.lib"
        COMMAND "${CMAKE_COMMAND}" -E touch "${_build_stamp}"
        DEPENDS "${CMAKE_CURRENT_LIST_FILE}" "${_source_dir}/configure"
        WORKING_DIRECTORY "${_build_dir_win}"
        VERBATIM
    )
    add_custom_target(ffmpeg-build ALL DEPENDS "${_build_stamp}")

    set(_libraries
        "${_install_dir}/lib/avfilter.lib"
        "${_install_dir}/lib/swscale.lib"
        "${_install_dir}/lib/avcodec.lib"
        "${_install_dir}/lib/avutil.lib"
        bcrypt ole32 strmiids mfuuid mfplat uuid d3d11 dxgi dxva2)

    set(FFmpeg_FOUND YES CACHE BOOL "" FORCE)
    set(FFmpeg_INCLUDE_DIR "${_install_dir}/include"
        CACHE PATH "Path to clang-cl FFmpeg headers" FORCE)
    set(FFmpeg_LIBRARIES "${_libraries}"
        CACHE STRING "clang-cl FFmpeg libraries" FORCE)
    set(FFmpeg_LDFLAGS "" CACHE STRING "FFmpeg linker flags" FORCE)
    set(FFmpeg_FOUND YES PARENT_SCOPE)
    set(FFmpeg_INCLUDE_DIR "${_install_dir}/include" PARENT_SCOPE)
    set(FFmpeg_LIBRARIES "${_libraries}" PARENT_SCOPE)
    set(FFmpeg_LDFLAGS "" PARENT_SCOPE)
endfunction()
