Hey there! Here's a quick reference for the Simple Billboard script.

Billboards are objects (typically 2D) that exist in a 3D environment and orient themselves toward the camera.
Some common use cases for billboarding are:

 - Characters or objects which need to always appear the same to the camera, regardless of viewing angle (think trees from Super Mario 64, or Nextbots)
 - 2D text and images represented consistently in a 3D world, such as quest markers or floating usernames
 - 3D models which billboard only on one axis, such as an indicator above a player which always faces toward the camera while still pointing down (Y-rotation only)

In the Example folder, you'll find a scene which shows 2 different kinds of billboarding (as well as a non-billboarding control for comparison).
To make your own things billboard, just add the SimpleBillboard script to your game object.

Keep in mind that an object in Unity rotates about its pivot point, so if you want your object to always appear firmly planted on the ground, you'll need to make sure the SimpleBillboard script is attached to an object positioned on the ground (usually Y = 0). If you have a mesh or sprite which you'd like to make billboard, but its pivot point is in the center, I recommend making a new parent game object with the SimpleBillboard script attached. This way, you can move the child sprite/mesh up to the correct position such that it sits flush with the ground while the Billboard parent object is at Y = 0. (Also, this is pretty much only relevant for X-axis billboarding or 'pitch'.)

The "Amount" and "Offset" vectors on the script can be used to modify your billboard's behavior by increasing or decreasing the intenstity of the effect and by modifying the default rotation direction respectively. The "Camera Override" can be used to specify a particular target camera instead of the main camera. Finally, the "Use Initial Rotation" toggle will always reset the changes made to the object's rotation in the previous tick before applying any new billboard math (this is useful when paired with the "Amount" vector for something like a 3D icon that only needs to tilt partially toward the camera, staying somewhat anchored to its original rotation).

Hope this tool can be of some use to you! Best of luck.
-Drew