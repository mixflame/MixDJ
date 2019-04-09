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

#include "chromagram.h"

namespace KeyFinder{

  Chromagram::Chromagram(unsigned int h, unsigned int b){
    hops = h;
    bins = b;
    chromaData = std::vector< std::vector<float> > (hops, std::vector<float> (bins, 0.0));
  }

  Chromagram::Chromagram(const Chromagram& that){
    hops = that.hops;
    bins = that.bins;
    chromaData = that.chromaData;
  }

  float Chromagram::getMagnitude(unsigned int h, unsigned int b) const{
    if(h >= hops){
      std::ostringstream ss;
      ss << "Cannot get magnitude of out-of-bounds hop (" << h << "/" << hops << ")";
      throw Exception(ss.str().c_str());
    }
    if(b >= bins){
      std::ostringstream ss;
      ss << "Cannot get magnitude of out-of-bounds bin (" << b << "/" << bins << ")";
      throw Exception(ss.str().c_str());
    }
    return chromaData[h][b];
  }

  void Chromagram::setMagnitude(unsigned int h, unsigned int b, float val){
    if(h >= hops){
      std::ostringstream ss;
      ss << "Cannot set magnitude of out-of-bounds hop (" << h << "/" << hops << ")";
      throw Exception(ss.str().c_str());
    }
    if(b >= bins){
      std::ostringstream ss;
      ss << "Cannot set magnitude of out-of-bounds bin (" << b << "/" << bins << ")";
      throw Exception(ss.str().c_str());
    }
    if(!isfinite(val)){
      throw Exception("Cannot set magnitude to NaN");
    }
    chromaData[h][b] = val;
  }

  void Chromagram::reduceTuningBins(const Parameters& params){
    unsigned int oct = params.getOctaves();
    if(bins == 12 * oct)
      return;
    if (params.getTuningMethod() == TUNING_BIN_ADAPTIVE){
      tuningBinAdaptive(params);
    }else{
      tuningHarte(params);
    }
  }

  void Chromagram::tuningHarte(const Parameters& params){
  /*
   * This is quite involved, and it's only an approximation of Harte's method
   * based on his thesis rather than a port of his code, but it works well for
   * e.g. Strawberry Fields Forever and other recordings he mentioned as being
   * difficult from a tuning perspective.
   */
    unsigned int oct = params.getOctaves();
    unsigned int bps = (bins/oct)/12;
    // find peaks; anything that's higher energy than the mean for this hop and higher energy than its neighbours.
    std::vector< std::vector<float> > peakLocations;
    std::vector< std::vector<float> > peakMagnitudes;
    for (unsigned int hop = 0; hop < hops; hop++){
      // find mean magnitude for this hop
      float meanVal = 0;
      for (unsigned int bin = 0; bin < bins; bin++){
        meanVal += chromaData[hop][bin];
      }
      meanVal /= bins;
      // find peak bins
      std::vector<unsigned int> peakBins;
      for (unsigned int bin = 1; bin < bins-1; bin++){
        float binVal = getMagnitude(hop,bin);
        // currently every peak over mean. Tried all peaks but accuracy dropped.
        if(binVal > meanVal && binVal > getMagnitude(hop,bin-1) && binVal > getMagnitude(hop,bin+1)){
          peakBins.push_back(bin);
        }
      }
      // quadratic interpolation to find a more precise peak position and magnitude.
      std::vector<float> peakLocationsRow;
      std::vector<float> peakMagnitudesRow;
      for (unsigned int peak=0; peak<peakBins.size(); peak++){
        float alpha = getMagnitude(hop,peakBins[peak] - 1);
        float beta  = getMagnitude(hop,peakBins[peak]);
        float gamma = getMagnitude(hop,peakBins[peak] + 1);
        float peakLocation = ((alpha - gamma)/(alpha - (2 * beta) + gamma))/2;
        float peakMagnitude = beta - ((1/4) * (alpha - gamma) * peakLocation);
        peakLocationsRow.push_back(peakBins[peak]+peakLocation);
        peakMagnitudesRow.push_back(peakMagnitude);
      }
      peakLocations.push_back(peakLocationsRow);
      peakMagnitudes.push_back(peakMagnitudesRow);
    }
    // determine tuning distribution of peaks. Centre bin = concert tuning.
    std::vector<float> peakTuningDistribution(bps*10);
    for (unsigned int hop = 0; hop < hops; hop++){
      for (unsigned int peak = 0; peak < peakLocations[hop].size(); peak++){
        float peakLocationMod = fmodf(peakLocations[hop][peak],(float)bps);
        peakLocationMod *= 10;
        unsigned int peakLocationInt = peakLocationMod + 0.5;
        peakLocationInt += 5;
        peakTuningDistribution[peakLocationInt%(bps*10)] += (peakMagnitudes[hop][peak] / 1000.0);
      }
    }
    // now find the tuning peak; the subdivision of a semitone that most peaks are tuned to.
    float tuningMax = 0;
    unsigned int tuningPeak = -1;
    for (unsigned int i=0; i<bps*10; i++){
      if(peakTuningDistribution[i] > tuningMax){
        tuningMax = peakTuningDistribution[i];
        tuningPeak = i;
      }
    }
    // now discard (zero out, for ease) any peaks that sit >= 0.2 semitones (e.g. 6 bins for 3bps) away from the tuning peak.
    // figure out which tuning bins to keep
    std::vector<unsigned int> binsToKeep;
    for (unsigned int i=(1-(bps*2)); i<bps*2; i++)
      binsToKeep.push_back((tuningPeak + i + (bps*10)) % (bps*10));
    // and discard the others
    std::vector<std::vector<float> > twelveBpoChroma(hops,std::vector<float>(12*oct));
    for (unsigned int hop = 0; hop < hops; hop++){
      for (unsigned int peak = 0; peak < peakLocations[hop].size(); peak++){
        float peakLocationMod = fmodf(peakLocations[hop][peak],(float)bps);
        peakLocationMod *= 10;
        unsigned int peakLocationInt = peakLocationMod + 0.5;
        peakLocationInt += 5;
        bool discardMe = true;
        for (unsigned int i=0; i<binsToKeep.size(); i++)
          if(peakLocationInt == binsToKeep[i])
            discardMe = false;
        if(!discardMe){ // this is a valid peak for the tuned chromagram
          unsigned int tunedPeakLocation = (unsigned int)peakLocations[hop][peak];
          tunedPeakLocation /= bps;
          twelveBpoChroma[hop][tunedPeakLocation] += peakMagnitudes[hop][peak];
        }
      }
    }
    chromaData = twelveBpoChroma;
    bins = 12 * oct;
  }

  void Chromagram::tuningBinAdaptive(const Parameters& params){
  /*
   * This is designed to tune for each semitone bin rather than for the whole
   * recording; aimed at dance music with individually detuned elements, rather
   * than music that is internally consistent but off concert pitch.
   */
    unsigned int oct = params.getOctaves();
    unsigned int bps = (bins/oct)/12;
    std::vector<std::vector<float> > twelveBpoChroma(hops,std::vector<float>(12*oct));
    for (unsigned int st = 0; st < 12*oct; st++){
      std::vector<float> oneSemitoneChroma(bps);
      for (unsigned int h = 0; h < hops; h++)
        for (unsigned int b = 0; b < bps; b++)
          oneSemitoneChroma[b] += chromaData[h][st*bps+b];
      // determine highest energy tuning bin
      unsigned int whichBin = 0;
      float max = oneSemitoneChroma[0];
      for (unsigned int i=1; i<bps; i++){
        if(oneSemitoneChroma[i] > max){
          max = oneSemitoneChroma[i];
          whichBin = i;
        }
      }
      for (unsigned int h = 0; h < hops; h++){
        float weighted = 0.0;
        for (unsigned int b = 0; b < bps; b++)
          weighted += (chromaData[h][st*bps+b] * (b == whichBin ? 1.0 : params.getDetunedBandWeight()));
        twelveBpoChroma[h][st] = weighted;
      }
    }
    chromaData = twelveBpoChroma;
    bins = 12 * oct;
  }

  void Chromagram::reduceToOneOctave(const Parameters& params){
    unsigned int oct = params.getOctaves();
    unsigned int bpo = bins/oct;
    if(bpo == bins)
      return;
    std::vector<std::vector<float> > oneOctaveChroma(hops,std::vector<float>(bpo));
    for (unsigned int h = 0; h < hops; h++){
      for (unsigned int b = 0; b < bpo; b++){
        float singleBin = 0.0;
        for (unsigned int o=0; o<oct; o++)
          singleBin += chromaData[h][o*bpo+b];
        oneOctaveChroma[h][b] = singleBin / oct;
      }
    }
    chromaData = oneOctaveChroma;
    bins = bpo;
  }

  unsigned int Chromagram::getHops() const{
    return hops;
  }

  unsigned int Chromagram::getBins() const{
    return bins;
  }

}
