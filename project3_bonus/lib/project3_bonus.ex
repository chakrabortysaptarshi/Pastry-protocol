defmodule PastryNode do
    use GenServer

    def init(messages) do
        {:ok, messages}
    end

    def add_gossip(pid, currentNodeId, newNodeId) do
        GenServer.cast(pid, {:add_gossip, currentNodeId, newNodeId})
    end

    def start_message(pid, total, destination, hops) do
        GenServer.cast(pid, {:start_message, total, destination, hops})
    end

    defp getRandomNode(current, total) do
        random = :rand.uniform(total)
        if random == current do
            getRandomNode(current, total)
        else
            random
        end
    end

    def lcp([]), do: ""
        def lcp(strs) do
        min = Enum.min(strs)
        max = Enum.max(strs)
        index = Enum.find_index(0..String.length(min), fn i -> String.at(min,i) != String.at(max,i) end)
        if index, do: String.slice(min, 0, index), else: min
    end

    # destnodeId is the integer value of the node and curnodeId is the integer value of current node
    defp getNextHop(messages, curnodeId, destnodeId) do
        curnodeId = getNodeName(curnodeId)
        totalLeafs = Enum.at(messages, 2) ++ Enum.at(messages, 3)
        if destnodeId >= Enum.at(totalLeafs, 0) and destnodeId <= Enum.at(totalLeafs, Kernel.length(totalLeafs)-1) do
            nextHop = Enum.min_by(totalLeafs, &abs(&1 - destnodeId)) 
        else
            curnodeIdStr = Integer.to_string(curnodeId, 16)
            destnodeIdStr = Integer.to_string(destnodeId, 16) 
            li = [curnodeIdStr] ++ [destnodeIdStr]
            #IO.inspect li
            length = String.length(lcp(li))
            dl = String.at(destnodeIdStr, length)
            dl = String.to_integer(dl, 16)
            routes = Enum.at(messages,4)
            rldl = Enum.at(Enum.at(routes, length), dl)
            if rldl != -1 do
                String.to_integer(rldl, 16)
            else
                ## add the complex logic
                md5_leaves = Enum.map(totalLeafs, fn(x) -> Integer.to_string(x,16) end)
                completeset = List.flatten(routes, md5_leaves)
                completeset = Enum.filter(completeset, fn(x) -> x != -1 end)
                nextNode = getSpecialNode(completeset, 0, curnodeId, destnodeId, length)
                String.to_integer(nextNode, 16)
            end
        end   
    end

    defp getSpecialNode(completeset, index, curnodeId, destnodeId, length) do
        if index < Kernel.length completeset do
            t = Enum.at(completeset, index)
            tint = String.to_integer(t)
            li = [t] ++ [ Integer.to_string(destnodeId, 16) ]
            len =  lcp(li)
            diff = abs(destnodeId - curnodeId) - abs(tint - destnodeId)
            if len >= length and diff > 0 do
                t
            end
        else
            getSpecialNode(completeset, index+1, curnodeId, destnodeId, length)
        end
    end 

    def handle_cast({:start_message, total, destination, hops}, messages) do
        # three different condtions need to be handled
        # 1. initial request to start the message passing
        # 2. forward the message tho another node
        # 3. stop the message propagation as this is the destination code
        #IO.puts "#{destination} #{Enum.at(messages, 0)}" 
        masternodeName = String.to_atom("nodemaster")
        requestsCompleted = Enum.at(messages, 1)
        if destination == Enum.at(messages, 0) do
            #IO.puts "Should terminate......... #{Enum.at(messages, 0)} <-> #{Enum.at(messages, 1)}"
            #if requestsCompleted >= 8 do 
            #MasterNode.counter(:global.whereis_name(masternodeName), 22222)
            #end
            messages = List.replace_at(messages,1, requestsCompleted+1)
            #Process.exit(self(),:kill)
        else
            if destination == -1 do
                #IO.puts "Starting message request"
                #MasterNode.counter(:global.whereis_name(masternodeName), 0)
                nextHop = message_send(messages, total, destination, hops)
                visitedNodeList = Enum.at(messages, 5) ++ [nextHop]
                messages = List.replace_at(messages, 5, visitedNodeList)
            else
                #handle the message forwarding case
                #:timer.sleep 1000
                MasterNode.counter(:global.whereis_name(masternodeName), 0)
                #IO.puts "Forwarding message request ....!!!!!!!!!!!!"
                nextHop = message_forward(messages, total, destination, hops)
                visitedNodeList = Enum.at(messages, 5) ++ [nextHop]
                messages = List.replace_at(messages, 5, visitedNodeList)
            end
        end
        {:noreply, messages}
    end
    
    defp message_forward(messages, total, destination, hops) do
        currentindex = Enum.at(messages, 0)
        random = destination
        #IO.puts "#{currentindex} -> #{random} hello forward message !!!"
        nodeId = getNodeName(random)
        # send for this particular node id
        # nexthop value should be md5 integer
        nextHop = getNextHop(messages, currentindex, nodeId)
        visitedNodes = Enum.at(messages, 5)
        newnodeName = String.to_atom("node#{nextHop}")

        if Enum.member?(Enum.at(messages, 6), nextHop) == true do
            # send failure message to master
            masternodeName = String.to_atom("nodemaster")
            MasterNode.counter(:global.whereis_name(masternodeName), 0)
            MasterNode.counter(:global.whereis_name(masternodeName), 0)
        end

        tempMap = visitedNodes |> Enum.reduce(%{}, fn x, acc -> Map.update(acc, x, 1, &(&1 + 1)) end)
        occurence = tempMap[nextHop] 
        if occurence == nil do
            occurence = 0
        end
        if Enum.member?(visitedNodes, nextHop) == true and occurence > 3 do
            #IO.puts "Detected collision @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
            ret = []
            ret
        else
            #IO.inspect :global.whereis_name(newnodeName)
            # initiate hops with zero and destination as the random node genrated as destination 
            PastryNode.start_message(:global.whereis_name(newnodeName), total, random, hops+1)
            nextHop
        end
    end

    defp message_send(messages, total, destination, hops) do
        currentindex = Enum.at(messages, 0)
        random = getRandomNode(currentindex, total)
        #IO.puts "#{currentindex} -> #{random} hello start message !!!"
        nodeId = getNodeName(random)
        # nexthop value should be md5 integer
        nextHop = getNextHop(messages, currentindex, nodeId)
        newnodeName = String.to_atom("node#{nextHop}")
        
        if Enum.member?(Enum.at(messages, 6), nextHop) == true do
            # send failure message to master
            masternodeName = String.to_atom("nodemaster")
            MasterNode.counter(:global.whereis_name(masternodeName), 0)
            MasterNode.counter(:global.whereis_name(masternodeName), 0)
        end
  
        # initiate hops with zero and destination as the random node genrated as destination 
        PastryNode.start_message(:global.whereis_name(newnodeName), total, random, 1)
        nextHop
        #cont_message_send(messages, total, destination, hops)
    end
     

    def handle_cast(:show_states, messages) do
        IO.inspect Enum.at(messages, 0)
        #IO.inspect Enum.at(messages, 2)
        #IO.inspect Enum.at(messages, 3)
        IO.inspect Enum.at(messages, 4)
        {:noreply, messages}
    end

    def handle_cast({:add_gossip, currentNodeId, newNodeId}, messages) do
        newMessages = messages
        if currentNodeId > newNodeId do
            li = Enum.at(messages, 2)
            if Kernel.length(li) > 15 do
                li = List.replace_at(li, 0, newNodeId)
            else
                li = li ++ [newNodeId]
            end
            li = Enum.sort(li)
            newMessages = List.replace_at(messages, 2, li)
        else
            li = Enum.at(messages, 3)
            if Kernel.length(li) > 15 do
                li = List.replace_at(li, 15, newNodeId)
            else
                li = li ++ [newNodeId]
            end
            li = Enum.sort(li)
            newMessages = List.replace_at(messages, 3, li)
        end

        # add code to update routing table
        currentNodeB16 = Integer.to_string(currentNodeId, 16)
        newNodeB16 = Integer.to_string(newNodeId, 16)
        routingTableLength = Kernel.length(Enum.at(messages, 4))
        newRoutingTable = updateRoutingTable(Enum.at(messages, 4), routingTableLength, newNodeB16, currentNodeB16)
        newMessages = List.replace_at(newMessages, 4, newRoutingTable)
        #IO.inspect Enum.at(newMessages, 2)
        #IO.inspect Enum.at(newMessages, 3)
        {:noreply, newMessages}
    end

    defp updateRoutingTable(routes, len, newNodeB16, current) do
        if len > 0 do
          # get char at position len of string newNodeB16 and convert the hex to integer. 
          # for that index check the routing table. If it is -1, replace it, otherwise leave it
          temp = String.at(newNodeB16, len-1)
            if temp != nil do
                index = String.to_integer(temp, 16)
                curRoutingVal = Enum.at(Enum.at(routes, len-1), index)
                #IO.inspect curRoutingVal
                if curRoutingVal == -1 do
                    #IO.puts "HEllo"
                    li = Enum.at(routes, len-1);
                    li = List.replace_at(li, index, newNodeB16)
                    routes = List.replace_at(routes, len-1, li)
                end
            #IO.inspect current
            #IO.inspect routes
            end
            updateRoutingTable(routes, len-1, newNodeB16, current)
        else
            routes
        end
    end

    defp selfRoutingTable(index, len, routes, current) do
        if index > 0  do
             newNodeId = getNodeName(index)
             newNodeB16 = Integer.to_string(newNodeId, 16)
             routes = updateRoutingTable(routes, len, newNodeB16, current)
             selfRoutingTable(index-1, len, routes, current)
        else
            routes
        end
    end

    def getNodeName(index) do
        hash = Base.encode16(:crypto.hash(:md5, Integer.to_string(index)))
        nodeId = String.to_integer(hash,16)
        nodeId    
    end

    defp selfLesserLeaf(index, currentNodeId, li) do
        if index > 0 do
            newNodeId = getNodeName(index)
            newli = li
            if(currentNodeId > newNodeId ) do
                if Kernel.length(newli) > 15 do
                    newli = List.replace_at(newli, 0, newNodeId)
                else
                    newli = newli ++ [newNodeId]
                end
            end
            selfLesserLeaf(index-1, currentNodeId, newli)
        else
            li
        end
    end

    defp selfGreaterLeaf(index, currentNodeId, li) do
        if index > 0 do
            newNodeId = getNodeName(index)
            newli = li
            if(currentNodeId < newNodeId ) do
                if Kernel.length(newli) > 15 do
                    newli = List.replace_at(newli, 15, newNodeId)
                else
                    newli = newli ++ [newNodeId]
                end
            end
            selfGreaterLeaf(index-1, currentNodeId, newli)
        else
            li
        end
    end

    def generateActors(index, totalNodes, routingTable, bonusnode) do
        if index <= totalNodes do
            #IO.puts "#####@@@@@@"
            nodeId = getNodeName(index)
            newnodeName = String.to_atom("node#{nodeId}")
            #IO.puts newnodeName
            lesserNodes = selfLesserLeaf(index-1,nodeId, []) 
            greaterNodes = selfGreaterLeaf(index-1,nodeId, []) 
            lesserNodes = Enum.sort(lesserNodes)
            greaterNodes = Enum.sort(greaterNodes)
            routingTableLength = Kernel.length(routingTable)
            routeTable = selfRoutingTable(index-1, routingTableLength, routingTable, index)
            {:ok, pid} = GenServer.start_link(PastryNode, [index, 1, lesserNodes, greaterNodes, routeTable, [], bonusnode] , name: newnodeName)
            :global.register_name(newnodeName,pid)
            sendArrivalMessage(index-1, nodeId)
            generateActors(index+1, totalNodes, routingTable, bonusnode)
        end
    end

    def sendArrivalMessage(index, newnodeId) do
        if index > 0 do
            nodeId = getNodeName(index)
            newnodeName = String.to_atom("node#{nodeId}")
            #IO.puts index
            PastryNode.add_gossip(:global.whereis_name(newnodeName), nodeId, newnodeId)
            sendArrivalMessage(index-1, newnodeId)
        end
    end

    def s(numNodes, numofRequests) do
        if numofRequests > 0 do
            messaging_init(numNodes, numNodes)
            :timer.sleep(1000)
            s(numNodes, numofRequests-1)
        end
    end

    def routingTableinit(num, constrow, mat) do 
        if num > 1 do
            newrow = constrow ++ mat 
            routingTableinit(num-1, constrow, newrow)
        else
            mat
        end
    end

   def messaging_init(currentNodeIndex, total) do
        if currentNodeIndex > 0 do
            nodeId = PastryNode.getNodeName(currentNodeIndex)
            newnodeName = String.to_atom("node#{nodeId}")
            #IO.inspect :global.whereis_name(newnodeName)
            # destination is -1 as the message is initiated from here and hops is zero
            PastryNode.start_message(:global.whereis_name(newnodeName), total, -1, 0)
            messaging_init(currentNodeIndex-1, total)
        end
   end

    def contd() do
        :timer.sleep 10000
        masternodeName = String.to_atom("nodemaster")
        MasterNode.track(:global.whereis_name(masternodeName))
        #contd()
    end
end


defmodule MasterNode do
    use GenServer

    def counter(pid, nodeId) do
        GenServer.cast(pid, {:increase_counter, nodeId})
    end

    def track(pid) do
        GenServer.call(pid, :track)
    end

    def handle_call(:track, _from, messages) do
        #IO.puts "#{Enum.at(messages, 0)} <-> #{Enum.at(messages, 1)}"
        averagehops = Enum.at(messages, 0) / Enum.at(messages, 1)
        IO.puts averagehops
        {:reply, messages, messages}
    end

    def handle_cast({:increase_counter, nodeId}, messages) do
        hops = Enum.at(messages, 0) + 1
        messages = List.replace_at(messages, 0, hops)        
        {:noreply, messages}
    end

    def getRandomBonusNode(totalNodes, bonusparam, nodes) do
      if bonusparam > 0 do
          bname = PastryNode.getNodeName(:rand.uniform(totalNodes))
          bonusnode = nodes ++ [bname]
          getRandomBonusNode(totalNodes, bonusparam-1, bonusnode)
      else
        nodes
      end
    end
end

defmodule Project3Bonus do
  def main(args) do
    numNodes = Enum.at(args,0) |> String.to_integer
    numofRequests = Enum.at(args,1) |> String.to_integer
    bonusparam = Enum.at(args,2) |> String.to_integer
    rows = 32
    constrow = [[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]] 
    routingTable = PastryNode.routingTableinit(rows, constrow, constrow)
    masternodeName = String.to_atom("nodemaster")
    {:ok, pid} = GenServer.start_link(MasterNode, [0, numNodes*numofRequests] , name: masternodeName)
    :global.register_name(masternodeName, pid)
    bonusnode = MasterNode.getRandomBonusNode(numNodes, bonusparam, [])
    bonusnode = Enum.uniq(bonusnode)
    #IO.inspect bonusnode
    PastryNode.generateActors(1, numNodes, routingTable, bonusnode)
    PastryNode.s(numNodes, numofRequests)
    IO.puts "Number of average hops"
    PastryNode.contd()
  end
end