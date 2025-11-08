#include "ns3/applications-module.h"
#include "ns3/core-module.h"
#include "ns3/flow-monitor-module.h"
#include "ns3/internet-module.h"
#include "ns3/network-module.h"
#include "ns3/ping-helper.h"
#include "ns3/point-to-point-module.h"
#include "ns3/traffic-control-module.h"

#include <string>

using namespace ns3;
int
main(int argc, char* argv[])
{
    int simulationTime = 20;
    std::string queueDiscType = "FifoQueueDisc";

    CommandLine cmd;
    cmd.AddValue("queueDiscType",
                 "Type of queue disc: FifoQueueDisc, CoDelQueueDisc, RedQueueDisc, etc.",
                 queueDiscType);
    cmd.Parse(argc, argv);

    NodeContainer sources, sink, router;

    // TODO

    std::cout << "Starting Simulation" << std::endl;
    Simulator::Stop(Seconds(simulationTime));
    Simulator::Run();
    Simulator::Destroy();
}
