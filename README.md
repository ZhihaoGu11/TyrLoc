# TyrLoc
**TyrLoc is a Low-cost Multi-technology MIMO Localization System with A Single RF Chain.**  
> + *Low-cost: Cheap SDR and inexpensive antenna array extension*  
> + *Multi-technology: Compatible with various protocols*  
> + *Single RF chain: A novel method to calibrate the phase distortion caused by CFO*  


## Requirements
**MATLAB R2020a**

**Add-Ons in MATLAB:**  
Signal Processing Toolbox  
WLAN Toolbox  
Communications Toolbox Library for the Bluetooth Protocol  
Communications Toolbox Support Package for Analog Devices ADALM-Pluto Radio  



**Adding the whole loder into the path**


## Getting Started  
1. Click [here](https://drive.google.com/drive/folders/1uhvyzDL-A9LQRhdQdebNI9TtZqHBKQlo?usp=sharing) to download the raw data and put it into the data folder.  

2. You can quickly use TyrLoc by running WIFIAoA_Main/BLEAoA_Main/LoRaAoA_Main.  

## Project Structure
    TyrLoc
    │  WIFIAoA_Main.m         // Main function of AoA estimation for WIFI  
    │  BLEAoA_Main.m          // Main function of BLE AoA estimation for BLE  
    │  LoRaAoA_Main.m         // Main function of LoRa AoA estimation for LoRa  
    │  
    ├─ wifi_helper            // Helper functions of detecting WIFI preamble  
    ├─ ble_helper             // Helper functions of detecting BLE preamble  
    ├─ lora_helper            // Helper functions of detecting LoRa preamble  
    │  
    ├─ util                   // Helper functions of antenna ID extraction, phase calibation and AoA estimation  
    │  
    └─ data  
        │  Data_Info.txt      // Some infomation of raw data  
        ├─ wifi_data          // Raw data of WIFI signal  
        ├─ ble_data           // Raw data of BLE signal  
        └─ lora_data          // Raw data of LoRa signal  
      

## Send us Feedback
Our work is open source for research purposes, and we want to polish it further!  
So let us know if you find/fix any bug or know how to speed up or improve any part of TyrLoc.  


## Citation
If TyrLoc hepls your research, please cite the paper in your publications.  

    @inproceedings{gu2021tyrloc,
      title={TyrLoc: a low-cost multi-technology MIMO localization system with a single RF chain},
      author={Gu, Zhihao and He, Taiwei and Yin, Junwei and Xu, Yuedong and Wu, Jun},
      booktitle={Proceedings of the 19th Annual International Conference on Mobile Systems, Applications, and Services},
      year={2021}
    }

