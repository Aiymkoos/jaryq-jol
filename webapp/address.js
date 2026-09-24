// Human-readable address, shared with the simple screen's reverse-geocoding approach.
export function spokenAddress(address){
 if(!address)return '';
 const street=address.road||address.pedestrian||address.footway;
 const area=address.suburb||address.neighbourhood||address.city_district;
 const city=address.city||address.town||address.village;
 return [street?(address.house_number?`${street}, ${address.house_number}`:street):'',area,!street?city:''].filter(Boolean).join(', ');
}
