// Copyright 2019, Collabora, Ltd.
// SPDX-License-Identifier: BSL-1.0 or GPL-2.0-only
/*!
 * @brief  Chunk of code that creates a EGL display and GL context.
 * @author Jakob Bornecrantz <jakob@collabora.com>
 */
module charge.core.egl;

import watt = [watt.conv, watt.library];

import amp.egl;
import amp.egl.loader;
import lib.gl.gl33;
import lib.gl.loader;

import charge.gfx.gl;


/*!
 * Holds all needed EGL state.
 */
struct EGL
{
	//! Simple logging function.
	log: dg(string);

	//! Loaded library.
	lib: watt.Library;

	dpy: EGLDisplay;
	cfg: EGLConfig;
	ctx: EGLContext;
}

fn initEGL(ref egl: EGL) bool
{
	egl.lib = loadEGL();
	if (egl.lib is null) {
		egl.log("Failed to load EGL!");
		return false;
	}

	if (!loadFuncs(egl.lib.symbol)) {
		egl.log("Failed to load EGL functions!");
		return false;
	}

	egl.dpy = eglGetDisplay(null);
	if (egl.dpy is null) {
		egl.log("Could not create EGLDisplay!");
		return false;
	}

	if (!eglInitialize(egl.dpy, null, null)) {
		egl.log("eglInitialize failed!");
		return false;	
	}

	attr: const(EGLint)[] = [
		EGL_RENDERABLE_TYPE,
		EGL_OPENGL_BIT,
		EGL_NONE,
	];

	num_config: EGLint;
	if (!eglChooseConfig(egl.dpy,
	                     attr.ptr,
	                     &egl.cfg,
	                     1,
	                     &num_config)) {
		egl.log("eglChooseConfig failed!");
		return false;
	}

	if (num_config < 1) {
		egl.log("We didn't get any config!");
		return false;
	}

	if (!eglBindAPI(EGL_OPENGL_API)) {
		egl.log("Failed bind OpenGL");
		return false;
	}

	ctx_attr: const(EGLint)[] = [
		EGL_CONTEXT_MAJOR_VERSION, 4,
		EGL_CONTEXT_MINOR_VERSION, 5,
		EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR,
		EGL_CONTEXT_OPENGL_DEBUG_BIT_KHR,
		EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR,
		EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
		EGL_NONE,
	];

	egl.ctx = eglCreateContext(egl.dpy, egl.cfg, EGL_NO_CONTEXT, ctx_attr.ptr);
	if (egl.ctx is EGL_NO_CONTEXT) {
		egl.log("We didn't get a context!");
		return false;
	}

	if (!eglMakeCurrent(egl.dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, egl.ctx)) {
		egl.log("Make current failed!");
		return false;
	}

	fn load(str: string) void*
	{
		return cast(void*)eglGetProcAddress(str.ptr);
	}

	if (!gladLoadGL(load)) {
		egl.log("Failed to load OpenGL functions!");
		return false;
	}

	// Setup the gfx sub-system.
	runDetection();
	printDetection();

	return true;
}

fn finiEGL(ref egl: EGL)
{
	if (egl.dpy !is null) {
		return;
	}

	eglMakeCurrent(egl.dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

	if (egl.ctx !is EGL_NO_CONTEXT) {
		eglDestroyContext(egl.dpy, egl.ctx);
		egl.ctx = EGL_NO_CONTEXT;
	}

	if (egl.dpy !is null) {
		// Can't free a display.
		egl.dpy = null;
	}

	return;
}
