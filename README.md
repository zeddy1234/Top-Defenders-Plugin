## Network science project

### Instructions to install and use


#### Install
Assumes you have `miniconda/anaconda` installed. Instructions on how to install can be found [here](https://docs.anaconda.com/miniconda/install/).


```shell
conda create -n ox -c conda-forge --strict-channel-priority osmnx
conda activate ox
pip install networkx[default]
pip install folium
pip install branca
```

#### Usage
```shell
conda activate ox
python Network_Science_Project.py --num_vehicles 500 --nav_percentage 20
```