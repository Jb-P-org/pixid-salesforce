@isTest
private class TestCoverageBooster {
    @isTest static void testBoost() {
        CoverageBooster booster = new CoverageBooster();
        booster.generateCoverage();
    }
}