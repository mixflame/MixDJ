/*************************************************************************

  Copyright 2011-2013 Ibrahim Sha'ath

  This file is part of LibKeyFinder.

  LibKeyFinder is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  LibKeyFinder is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with LibKeyFinder.  If not, see <http://www.gnu.org/licenses/>.

*************************************************************************/

#include "lowpassfilterfactory.h"

namespace KeyFinder{

  LowPassFilterWrapper::LowPassFilterWrapper(unsigned int cc, unsigned int fr, float cf, unsigned int fs, LowPassFilter* fi){
    coefficientCount = cc;
    frameRate = fr;
    cornerFrequency = cf;
    fftFrameSize = fs;
    lpf = fi;
  }

  LowPassFilterWrapper::~LowPassFilterWrapper(){
    delete lpf;
  }

  LowPassFilter* LowPassFilterWrapper::getLowPassFilter() const{
    return lpf;
  }

  unsigned int LowPassFilterWrapper::getCoefficientCount() const{
    return coefficientCount;
  }

  unsigned int LowPassFilterWrapper::getFrameRate() const{
    return frameRate;
  }

  float LowPassFilterWrapper::getCornerFrequency() const{
    return cornerFrequency;
  }

  unsigned int LowPassFilterWrapper::getFftFrameSize() const{
    return fftFrameSize;
  }

  LowPassFilterFactory::LowPassFilterFactory(){
    filters = std::vector<LowPassFilterWrapper*>(0);
  }

  LowPassFilterFactory::~LowPassFilterFactory(){
    for (unsigned int i=0; i<filters.size(); i++)
      delete filters[i];
  }

  LowPassFilter* LowPassFilterFactory::getLowPassFilter(unsigned int cc, unsigned int fr, float cf, unsigned int fs){
    for (unsigned int i=0; i<filters.size(); i++){
      LowPassFilterWrapper* wrapper = filters[i];
      if(
        wrapper->getCoefficientCount() == cc &&
        wrapper->getFrameRate() == fr &&
        wrapper->getCornerFrequency() == cf &&
        wrapper->getFftFrameSize() == fs
      ){
        return wrapper->getLowPassFilter();
      }
    }
    filters.push_back(
      new LowPassFilterWrapper(
        cc, fr, cf, fs, new LowPassFilter(cc, fr, cf, fs)
      )
    );
    return filters[filters.size()-1]->getLowPassFilter();
  }

}
