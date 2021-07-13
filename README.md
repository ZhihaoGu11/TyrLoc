# TyrLoc
**TyrLoc is a Low-cost Multi-technology MIMO Localization System with A Single RF Chain.**  
> + *Low-cost: Cheap SDR and inexpensive antenna array extension*  
> + *Multi-technology: Compatible with various protocols*  
> + *Single RF chain: A novel method to calibrate the phase distortion caused by CFO*  

## Requirements
**MATLAB R2020a**

**Add-Ons:**  
Signal Processing Toolbox  
Communications Toolbox Support Package for Analog Devices ADALM-Pluto Radio  
Communications Toolbox Library for the Bluetooth Protocol  

**Adding the whole Floder into the path**

## Getting Started
1. Click here to download the raw data and put it into the folder.  
2.You can quickly use TyrLoc by run WIFIAoA_Main/BLEAoA_Main/LoRaAoA_Main.  

## Project Structure
    TyrLoc
    │  WIFIAoA_Main.m          // Main function of AoA estimation for WIFI  
    │  BLEAoA_Main.m           // Main function of BLE AoA estimation for BLE  
    │  LoRaAoA_Main.m          // Main function of LoRa AoA estimation for LoRa  
    ├─ wifi  
    │  │  WIFIAoAEst.m         // AoA estimator for BLE  
    │  └─ ble_detecor_util     // Helper function of detecting WIFI preamble  
    ├─ ble  
    │  │  BLEAoAEst.m          // AoA estimator for LoRa  
    │  └─ lora_detector_util   // Helper functions of detecting BLE preamble  
    ├─ lora  
    │   │  LoRaAoAEst.m        // AoA estimator for LoRa  
    │   └─ wifi_detector_util  // Helper functions of detecting LoRa preamble  
    ├─ util                    // Helper functions of antenna ID extraction, phase calibation and AoA estimation  
    └─ data
        │  Data_Info.txt       // Some infomation of raw data  
        ├─ wifi_data           // Raw data of BLE signal  
        ├─ ble_data            // Raw data of BLE signal  
        └─ lora_data           // Raw data of LoRa signal  
      
      
## Send us Feedback!
Our work is open source for research purposes, and we want to polish it further!  
So let us know if you find/fix any bug or know how to speed up or improve any part of TyrLoc.  

## Citation
    @inproceedings{gu2021tyrloc,  
    author = {Gu, Zhihao and He, Taiwei and Yin, Junwei and Xu, Yuedong and Wu, Jun},  
    title = {TyrLoc: A Low-Cost Multi-Technology MIMO Localization System with a Single RF Chain},  
    year = {2021}  
    }  

