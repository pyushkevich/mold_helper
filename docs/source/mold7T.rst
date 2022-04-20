Building a Mold using a 7T MRI scan of the MTL
==============================================

About this Protocol
-------------------
Use this protocol when you have scanned the entire MTL specimen on a 7T MRI scanner. The 7T MRI introduces minimal distortion to the tissue and can be used directly for mold generation. By contrast, the animal 9.4T scaner introduces distortions that have to be corrected by registration to a 7T scan first.

Step 1. Download Input MRI Scan
-------------------------------
Create a new folder for each mold-making project. All files should be saved in this folder. 

The required input to this protocol is a 7T MRI scan of the MTL. It should be converted to the NiFTI file format and saved as :code:`mtl7t.nii.gz`

* When selecting the 7T scan, **do not** use the scan with the :code:`_nd` in its name. Those images are saved without on-the-scanner distortion correction and are not suitable for mold making.

Step 2. Segment the MTL from the Background in ITK-SNAP
-------------------------------------------------------

1. Load :code:`mtl7t.nii.gz` into ITK-SNAP

2. Enter the automatic (snake) segmentation mode

3. Enter “classification” pre-segmentation mode

4. Label the tissue as “red” label, and background (fomblin) as “green” label

   * If there is some water on top of the sample, label it with another label 

   .. image:: images/snake1.png

5. Under “More…” set the “Neighborhood size” to 2

.. image:: images/snake2.png
   :width: 200px
   :align: center

6. Click “Train Classifier” to isolate foreground from background

7. Repeat this process (adding training samples where the classifier messes up and retraining classifier) until satisfied with the pre-segmentation.

8. Under "More...", save the classifier training samples as :code:`training_samples.nii.gz` 
   
9.  Click “Next” to enter bubble placement mode

10. Move your cursor around the sample and click **Add Bubble at Cursor** to place bubbles. 
    
11. Click **Next** again and run contour (snake) evolution by clicking the play button. Verify that the segmentation is good. **Do not** press *Finish* yet.

.. image:: images/snake3.png

12.  Before clicking **Finish**, open the layer inspector window (`Tools -> Layer Inspector…`) and save the **evolving contour** layer as :code:`contour_image.nii.gz`.
    
13. Exit the segmentation mode. You do not need to save the actual segmentation

Step 3. Create a Reference Mold
===============================









