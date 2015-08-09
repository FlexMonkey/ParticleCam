# ParticleCam
## Metal based particle system influenced by iPad camera

Companion project to this blog post: http://flexmonkey.blogspot.co.uk/2015/08/ios-live-camera-controlled-particles-in.html

My latest Swift and Metal experiment borrows from my recent post Generating & Filtering Metal Textures From Live Video and from my numerous posts about my Metal GPU based particle system, ParticleLab.

ParticleCam is a small app that takes the luminosity layer from the device's rear camera and passes it into my particle shader. In the shader code, I look at the value of each particle's neighbouring pixels and, after a bit of averaging, adjust that particle's linear momentum so that it moves towards brighter areas of the camera feed.

With the Retina Display of my iPad Air 2, the final result is an ethereal, nebulous particle system that reflects the image. It works well with slow moving subjects that contrast against a fairly static background. The video above was created by pointing my iPad at a screen running a video of a woman performing Tai Chi. The screen recording was done using QuickTime and sadly seems to have lost a little of that ethereal quality in compression.

The source code for ParticleCam is available at my GitHub repository here. I've only tested it on my iPad Air 2 using Xcode 7.0 beta 5 and iOS 9 beta 5.
