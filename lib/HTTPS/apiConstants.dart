class URLConstants {
  //test
  static const String baseUrl = "https://1905.i2g20.com/api";
  //Live
  //static const String baseUrl = "https://1905.inspect2go55.com/api";

  //https://douglas.i2g20.com
  static const String login = "/login";
  static const String inspectorList = "inspector";
  static const String mobileFoodPermits = "/mobile-food/get-permit-list-by-pagination";
  static const String mobileFoodSectionList = "/mobile-food/sections-list";
  static const String mobileFoodSectionPartsList = "/mobile-food/section-parts-list";
  static const String mobileFoodItemList = "/mobile-food/items-list";
  static const String mobileFoodOOperationTypesList = "/mobile-food/operation-types";
  static const String mobileFoodInspection = "/mobile-food/inspection";
  static const String mobileFooditemListSubmit = "/mobile-food/inspection-item";

  static const String mobileFoodTemperatureSubmit = "/mobile-food/item-temperature";
  static const String mobileFoodInspectionSchedule = "/mobile-food/get-inspection-shedules-by-pagination";

  //Food
  static const String getFoodPermitList = "/food/get-permit-list";
  static const String getFoodSectionList = "/food/sections-list";
  static const String getFoodSectionPartsList = "/food/section-parts-list";
  static const String getFoodItemList = "/food/items-list";
  
  static const String foodInspection = "/food/inspection";
  static const String foodItemListSubmit = "/food/inspection-item";
  static const String foodTemperatureSubmit = "/food/item-temperature";
  static const String foodInspectionSchedule = "/food/get-inspection-shedules-by-pagination";

  //Temp Food
  static const String tempFoodPermitList = "/temp-food/get-permit-list-by-pagination";
  static const String tempFoodSectionList = "/temp-food/sections-list";
  static const String tempFoodSectionPartsList = "/temp-food/section-parts-list";
  static const String getTempFoodItemList = "/temp-food/items-list";

  static const String tempFoodInspection = "/temp-food/inspection";
  static const String tempFoodListSubmit = "/temp-food/inspection-item";
  static const String tempFoodTemperatureSubmit = "/temp-food/item-temperature-array-submit";
  static const String tempFoodInspectionSchedule = "/temp-food/get-inspection-schedules-by-pagination";

  //Tobacco
  static const String tobaccoPermitList = "/tobacco/get-permit-list-by-pagination";
  static const String tobaccoSectionList = "/tobacco/get-section-details";
  static const String tobaccoInspectionScheduleList = "/tobacco/get-inspection-shedules-by-pagination";
  static const String tobaccoInspectionSubmit = "/tobacco/inspection";
  static const String tobaccoInspectionItemSubmit = "/tobacco/inspection-details";
}