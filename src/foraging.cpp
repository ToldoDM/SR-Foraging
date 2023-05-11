#include "foraging.h"

/****************************************/
/****************************************/

static const Real RADIUS_NEST   = 0.75f;
static const Real RADIUS_SOURCE = 0.5f;

static const Real SOURCE_MINR   = 5.0f;
static const Real SOURCE_MAXR   = 5.5f;

static const Real FORB_A_MINR   = 1.75f;
static const Real FORB_A_MAXR   = 2.25f;
static const Real FORB_B_MINR   = 3.25f;
static const Real FORB_B_MAXR   = 3.75f;
static const CRadians FORB_A_DT  = CRadians(0.35);
static const CRadians FORB_B_DT  = CRadians(0.20);

/****************************************/
/****************************************/

CForaging::CForaging()
{
	m_unNbrItemsCollected = 0;
	m_unTimeStep = 0;
}

/****************************************/
/****************************************/

CForaging::~CForaging() {}

/****************************************/
/****************************************/

void CForaging::Init(TConfigurationNode& t_tree)
{
	GetNodeAttribute(t_tree, "output", m_strOutFile);
	Init();
}

/****************************************/
/****************************************/

void CForaging::Init()
{
	/* Open the file for text writing */
	m_cOutFile.open(m_strOutFile.c_str(), std::ofstream::out | std::ofstream::trunc);
	if (m_cOutFile.fail())
	{
		THROW_ARGOSEXCEPTION("Error opening file \"" << m_strOutFile << "\": " << ::strerror(errno));
	}

	m_pcRNG = CRandom::CreateRNG("argos");

	/* Random position for the source*/
	CRange<Real> cRangeR(SOURCE_MINR, SOURCE_MAXR);
	CRange<CRadians> cRangeT(CRadians::SIGNED_RANGE);
	m_cCoordSource = CVector2(m_pcRNG->Uniform(cRangeR), m_pcRNG->Uniform(cRangeT));

	/* Position of the nest */
	m_cCoordNest = CVector2(0.0f, 0.0f);
	m_unNbrItemsCollected = 0;

	/* Position of the light source */
	CSpace::TMapPerType& m_cLight = GetSpace().GetEntitiesByType("light");
	for (CSpace::TMapPerType::iterator it = m_cLight.begin(); it != m_cLight.end(); ++it)
	{
		/* Get handle to foot-bot entity and controller */
		CLightEntity& cLight = *any_cast<CLightEntity*>(it->second);
		/* Set the position of the light source over the food source*/
		cLight.SetPosition(CVector3(m_cCoordSource.GetX(),m_cCoordSource.GetY(),0.5));
	}

	/* Initialise food data for the robots */
	CSpace::TMapPerType& m_cFootbots = GetSpace().GetEntitiesByType("foot-bot");
	//m_unNumRobots = m_cFootbots.size();
	//for (size_t i = 0; i < m_unNumRobots; ++i)
	m_unNumRobots = 0;
	for (CSpace::TMapPerType::iterator it = m_cFootbots.begin(); it != m_cFootbots.end(); ++it)
	{
		m_sFoodData.push_back(0);
		m_unNumRobots = m_unNumRobots + 1;
	}

	// std::cout << "m_unNumRobots: " << m_unNumRobots << std::endl;

	/* Random position of the robots */
	MoveRobots();

	/* Write the header of the output file */
	m_cOutFile << "#Clock\tItemsCollected" << std::endl;
}

/****************************************/
/****************************************/

void CForaging::Reset()
{
	/* Close the output file */
	m_cOutFile.close();
	if (m_cOutFile.fail())
	{
		THROW_ARGOSEXCEPTION("Error closing file \"" << m_strOutFile << "\": " << ::strerror(errno));
	}

	m_sFoodData.clear();

	Init();

	/* Reseting the variables. */
	for (size_t i = 0; i < m_unNumRobots; ++i)
	{
		m_sFoodData.at(i) = 0;
	}
	m_unNbrItemsCollected = 0;
	m_unTimeStep = 0;

	/* Erasing content of file. Writing new header. */
	m_cOutFile << "#Clock\tItems" << std::endl;
}

/****************************************/
/****************************************/

void CForaging::Destroy()
{
	/* Close the output file */
	m_cOutFile.close();
	if (m_cOutFile.fail())
	{
		THROW_ARGOSEXCEPTION("Error closing file \"" << m_strOutFile << "\": " << ::strerror(errno));
	}
}

/****************************************/
/****************************************/

void CForaging::PreStep() {}

/****************************************/
/****************************************/

void CForaging::PostStep()
{
	UInt32 sCurrentScore = m_unNbrItemsCollected;
	CSpace::TMapPerType& m_cFootbots = GetSpace().GetEntitiesByType("foot-bot");
	UInt64 unRobotId;
	for(CSpace::TMapPerType::iterator it = m_cFootbots.begin(); it != m_cFootbots.end(); ++it)
	{
		/* Get handle to foot-bot entity and controller */
		CFootBotEntity& cFootBot = *any_cast<CFootBotEntity*>(it->second);
		/* Get the position of the foot-bot on the ground as a CVector2 */
		CVector2 cPos;
		cPos.Set(cFootBot.GetEmbodiedEntity().GetOriginAnchor().Position.GetX(), cFootBot.GetEmbodiedEntity().GetOriginAnchor().Position.GetY());
		unRobotId = atoi(cFootBot.GetId().substr(2, 3).c_str());
		/* If the foot-bot is on the nest, drop the item he is carrying. */
		if (IsOnNest(cPos))
		{
			if (m_sFoodData.at(unRobotId-1) != 0)
			{
				m_unNbrItemsCollected += 1;
				m_sFoodData.at(unRobotId-1) = 0;
			}
		}
		/* If the foot-bot is on source, takes corresponding item */
		else if (IsOnSource(cPos))
		{
			m_sFoodData.at(unRobotId-1) = 1;
		}
		/* If the foot-bot is on the forbbiden areas, looses corresponding item */
		else if (IsOnForbidden(cPos))
		{
			m_sFoodData.at(unRobotId-1) = 0;
		}
	}
	
	/* Increase the time step counter */
	m_unTimeStep += 1;
	
	/* Writting data to output file. */
	m_cOutFile << m_unTimeStep << "\t" << m_unNbrItemsCollected << std::endl;
	
	/* Output in simulator */
	if (m_unNbrItemsCollected > sCurrentScore)
	{
		LOGERR << "Items collected = " << m_unNbrItemsCollected << std::endl;
	}
}

/****************************************/
/****************************************/

void CForaging::PostExperiment()
{
	LOG << "Items collected = " << m_unNbrItemsCollected << std::endl;
}

/****************************************/
/****************************************/

CColor CForaging::GetFloorColor(const CVector2& c_position_on_plane)
{
	/* Source area is black */
	CVector2 vCurrentPoint(c_position_on_plane.GetX(), c_position_on_plane.GetY());
	Real d = (m_cCoordSource - vCurrentPoint).Length();
	if (d <= RADIUS_SOURCE)
	{
		return CColor::BLACK;
	}
	
	/* Nest area is white */
	d = (m_cCoordNest - vCurrentPoint).Length();
	if (d <= RADIUS_NEST)
	{
		return CColor::WHITE;
	}
	
	/* Inner forbidden area. FORB A */
	CRadians t = (vCurrentPoint - m_cCoordNest).Angle().UnsignedNormalize();
	if (d <= FORB_A_MAXR && d >= FORB_A_MINR)
	{
		bool in_forb = true;
		for (size_t i = 0; i < 5; ++i)
		{
			if (t < CRadians::PI_OVER_TWO*i + FORB_A_DT
			    && t > CRadians::PI_OVER_TWO*i - FORB_A_DT)
			{
				in_forb = false;
				break;
			}
		}
		if (in_forb)
		{
			return CColor::GRAY20;
		}
	}

	/* Outer forbidden area. FORB B */
	if (d <= FORB_B_MAXR && d >= FORB_B_MINR)
	{
		bool in_forb = true;
		for (size_t i = 0; i < 5; ++i)
		{
			if (t < CRadians::PI_OVER_TWO*i + CRadians::PI_OVER_FOUR + FORB_B_DT
			    && t > CRadians::PI_OVER_TWO*i + CRadians::PI_OVER_FOUR - FORB_B_DT)
			{
				in_forb = false;
				break;
			}
		}
		if (in_forb)
		{
			return CColor::GRAY20;
		}
	}

	/* Rest of the arena is gray. */
	return CColor::GRAY60;
}

/****************************************/
/****************************************/

bool CForaging::IsOnForbidden(CVector2& c_position_robot)
{
	Real r = c_position_robot.Length();
	CRadians t = c_position_robot.Angle().UnsignedNormalize();
	
	/* Inner forbidden area. FORB A */
	if (r <= FORB_A_MAXR && r >= FORB_A_MINR)
	{
		bool in_forb = true;
		for (size_t i = 0; i < 5; ++i)
		{
			if (t < CRadians::PI_OVER_TWO*i + FORB_A_DT
			    && t > CRadians::PI_OVER_TWO*i - FORB_A_DT)
			{
				in_forb = false;
				break;
			}
		}
		if (in_forb)
		{
			return true;
		}
	}

	/* Outer forbidden area. FORB B */
	if (r <= FORB_B_MAXR && r >= FORB_B_MINR)
	{
		bool in_forb = true;
		for (size_t i = 0; i < 5; ++i)
		{
			if (t < CRadians::PI_OVER_TWO*i + CRadians::PI_OVER_FOUR + FORB_B_DT
			    && t > CRadians::PI_OVER_TWO*i + CRadians::PI_OVER_FOUR - FORB_B_DT)
			{
				in_forb = false;
				break;
			}
		}
		if (in_forb)
		{
			return true;
		}
	}

	return false;
}

/****************************************/
/****************************************/

bool CForaging::IsOnNest(CVector2& c_position_robot)
{
	if ((m_cCoordNest - c_position_robot).Length() <= RADIUS_NEST)
	{
		return true;
	}
	return false;
}

/****************************************/
/****************************************/

bool CForaging::IsOnSource(CVector2& c_position_robot)
{
	if ((m_cCoordSource - c_position_robot).Length() <= RADIUS_SOURCE)
	{
		return true;
	}
	return false;
}

/****************************************/
/****************************************/

void CForaging::MoveRobots()
{
	CFootBotEntity* pcFootBot;
	bool bPlaced = false;
	UInt32 unTrials;
	CSpace::TMapPerType& tFootBotMap = GetSpace().GetEntitiesByType("foot-bot");
	for (CSpace::TMapPerType::iterator it = tFootBotMap.begin(); it != tFootBotMap.end(); ++it)
	{
		pcFootBot = any_cast<CFootBotEntity*>(it->second);
		// Choose position at random
		unTrials = 0;
		do
		{
		   ++unTrials;
		   CVector3 cFootBotPosition = GetRandomPosition();
		   bPlaced = MoveEntity(pcFootBot->GetEmbodiedEntity(),
		                        cFootBotPosition,
		                        CQuaternion().FromEulerAngles(m_pcRNG->Uniform(CRadians::UNSIGNED_RANGE),
		                        CRadians::ZERO,CRadians::ZERO),false);
		}
		while(!bPlaced && unTrials < 100);
		if(!bPlaced)
		{
			THROW_ARGOSEXCEPTION("Can't place robot");
		}
	}
}

/****************************************/
/****************************************/

CVector3 CForaging::GetRandomPosition()
{
	Real r = m_pcRNG->Uniform(CRange<Real>(0.0f, 1+FORB_B_MAXR));
	CRadians t = m_pcRNG->Uniform(CRange<CRadians>(CRadians::SIGNED_RANGE));
	return CVector3(r, CRadians::PI_OVER_TWO, t);
}

/****************************************/
/****************************************/

/* Register this loop functions into the ARGoS plugin system */
REGISTER_LOOP_FUNCTIONS(CForaging, "foraging");
