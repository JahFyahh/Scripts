#!/bin/sh
# Scripted installation of OpenCV
# All credits go to www.pyimagesearch.com

# delete Wolfram
sudo apt-get purge wolfram-engine

# Install dependencies
sudo apt-get install build-essential cmake pkg-config
sudo apt-get install libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
sudo apt-get install libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
sudo apt-get install libxvidcore-dev libx264-dev
sudo apt-get install libgtk2.0-dev
sudo apt-get install libatlas-base-dev gfortran
sudo apt-get install python2.7-dev python3-dev

# Download the OpenCV source code
cd ~
wget -O opencv.zip https://github.com/Itseez/opencv/archive/3.1.0.zip
unzip opencv.zip

wget -O opencv_contrib.zip https://github.com/Itseez/opencv_contrib/archive/3.1.0.zip
unzip opencv_contrib.zip

# Install Python
wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py

# Install Virtualenv
sudo pip install virtualenv virtualenvwrapper
sudo rm -rf ~/.cache/pip

# Update ~/.profile for virtualenv
echo -e "\n# virtualenv and virtualenvwrapper" >> ~/.profile
echo "export WORKON_HOME=$HOME/.virtualenvs" >> ~/.profile
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.profile

# reload virtualenv
source ~/.profile

# Create python virtualenv
mkvirtualenv cv -p python2
source ~/.profile

# Installing NumPy
pip install numpy

# Compile and Install OpenCV
workon cv
cd ~/opencv-3.1.0/
mkdir build
cd build
cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D INSTALL_PYTHON_EXAMPLES=ON \
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib-3.1.0/modules \
    -D BUILD_EXAMPLES=ON ..

# make
make -j4
make clean
make
sudo make install
sudo ldconfig

# Finilze installation
cd ~/.virtualenvs/cv/lib/python2.7/site-packages/
ln -s /usr/local/lib/python2.7/site-packages/cv2.so cv2.so

# exit and reload virtualenv CV
deactivate
source ~/.profile

# Clean up files
rm -rf opencv-3.1.0 opencv_contrib-3.1.0

# Notify that OpenCV is installed via PushBullet
curl https://api.pushbullet.com/v2/pushes -X POST -u o.Hymz6z7xUn9W4tAaSuQiMARNKGFXX0SF: --header "Content-Type: application/json" --data-binary "{\"device_iden\": \"ujxgSNfqYnIsjzY8CyoHO8\", \"type\": \"note\", \"title\":\"PiBakery\", \"body\": \"'OpenCV is Done'\"}"